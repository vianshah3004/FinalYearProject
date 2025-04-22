import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class OBDData extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataUpdated;
  final Function(bool, bool) onConnectionStatusChanged; // New callback: (isConnected, wasDisconnected)

  const OBDData({
    required this.onDataUpdated,
    required this.onConnectionStatusChanged,
    Key? key,
  }) : super(key: key);

  @override
  _OBDDataState createState() => _OBDDataState();
}

class _OBDDataState extends State<OBDData> {
  BluetoothConnection? connection;
  bool isConnected = false;
  bool wasConnected = false; // Track if the device was previously connected
  String statusMessage = "Disconnected";
  List<String> logMessages = [];
  Timer? connectionTimer;
  Timer? dataTimer;

  Map<String, dynamic> obdData = {
    "RPM": 0.0,
    "Speed": 0.0,
    "Engine Load": 0.0,
    "Coolant Temp": 0.0,
    "Intake Temp": 0.0,
    "Throttle Position": 0.0,
    "Battery Voltage": 0.0,
    "Fuel Pressure": 0.0,
    "Timing Advance": 0.0,
    "MAF Air Flow": 0.0,
    "VIN": "",
    "DTCs": [],
  };

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startConnectionAttempts();
  }

  void _addLog(String message) {
    logMessages.insert(0, "${DateTime.now().toString().substring(11, 19)}: $message");
    if (logMessages.length > 50) logMessages.removeLast();
    print(message);
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (statuses.values.any((status) => status.isDenied)) {
      _addLog("Permissions denied - please grant them in settings");
      setState(() => statusMessage = "Permissions required");
    } else {
      _addLog("Permissions granted");
    }
  }

  void _startConnectionAttempts() {
    connectionTimer?.cancel();
    connectionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!isConnected) {
        _addLog("Attempting to connect to OBD device...");
        connectToOBDDevice();
      } else {
        timer.cancel();
        _addLog("Connection established, stopping retry timer");
      }
    });
  }

  Future<void> connectToOBDDevice() async {
    if (isConnected) return;

    try {
      setState(() => statusMessage = "Scanning paired devices...");
      _addLog("Fetching paired devices");

      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? obdDeviceCandidate;

      for (var device in devices) {
        String? name = device.name;
        String displayName = name ?? "Unnamed";
        _addLog("Found: $displayName - ${device.address}");
        if (name != null && (name.toLowerCase().contains('obd') || name.toLowerCase().contains('elm'))) {
          obdDeviceCandidate = device;
          break;
        }
      }

      if (obdDeviceCandidate == null) {
        setState(() => statusMessage = "No OBD device found");
        _addLog("No OBD device - pair it first");
        return;
      }

      final BluetoothDevice obdDevice = obdDeviceCandidate;
      setState(() => statusMessage = "Connecting to ${obdDevice.name ?? 'Unnamed'}...");
      connection = await BluetoothConnection.toAddress(obdDevice.address);
      _addLog("Connected successfully");

      setState(() {
        isConnected = true;
        statusMessage = "Connected";
      });

      // Notify HomeScreen of connection status
      widget.onConnectionStatusChanged(isConnected, false);

      connection!.input!.listen(_onDataReceived).onDone(() {
        if (isConnected) _disconnect();
      });

      // Initial setup commands
      await _sendATCommand("ATZ\r");
      await Future.delayed(Duration(milliseconds: 500));
      await _sendATCommand("ATE0\r");
      await Future.delayed(Duration(milliseconds: 500));
      await _sendATCommand("ATL0\r");
      await Future.delayed(Duration(milliseconds: 500));
      await _sendATCommand("ATSP0\r");
      await Future.delayed(Duration(milliseconds: 500));

      await _sendATCommand("0902\r");
      await Future.delayed(Duration(milliseconds: 500));

      await _sendATCommand("03\r");
      await Future.delayed(Duration(milliseconds: 500));

      _startDataPolling();
    } catch (e) {
      setState(() {
        isConnected = false;
        statusMessage = "Connection Failed";
      });
      // Notify HomeScreen of connection status
      widget.onConnectionStatusChanged(isConnected, wasConnected);
      _addLog("Connection error: $e");
    }
  }

  Future<void> _sendATCommand(String command) async {
    if (connection == null || !isConnected) return;
    try {
      connection!.output.add(ascii.encode(command));
      await connection!.output.allSent;
      _addLog("Sent: $command");
    } catch (e) {
      _addLog("Send command error: $e");
    }
  }

  void _startDataPolling() {
    int pollCount = 0;
    dataTimer?.cancel();
    dataTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) async {
      if (!isConnected) {
        timer.cancel();
        _startConnectionAttempts();
        return;
      }
      await _sendATCommand("0104\r");
      await _sendATCommand("0105\r");
      await _sendATCommand("010A\r");
      await _sendATCommand("010C\r");
      await _sendATCommand("010D\r");
      await _sendATCommand("010E\r");
      await _sendATCommand("010F\r");
      await _sendATCommand("0110\r");
      await _sendATCommand("0111\r");
      await _sendATCommand("0142\r");

      pollCount++;
      if (pollCount % 10 == 0) {
        await _sendATCommand("03\r");
      }
    });
  }

  void _onDataReceived(Uint8List data) {
    String response = ascii.decode(data).trim();
    _addLog("Received: $response");
    _parseResponse(response);
  }

  void _parseResponse(String response) {
    if (response.isEmpty) return;

    List<String> lines = response.split(RegExp(r'[\r\n]+')).where((line) => line.isNotEmpty).toList();

    for (String line in lines) {
      line = line.trim();
      if (!line.startsWith("41") && !line.startsWith("43") && !line.startsWith("49")) continue;

      List<String> parts = line.split(" ");
      if (parts.length < 2) {
        _addLog("Invalid response format: $line");
        continue;
      }

      String mode = parts[0];

      try {
        setState(() {
          if (mode == "41") {
            String pid = parts[1];
            switch (pid) {
              case "04":
                obdData["Engine Load"] = (int.parse(parts[2], radix: 16) * 100.0) / 255.0;
                break;
              case "05":
                obdData["Coolant Temp"] = int.parse(parts[2], radix: 16) - 40.0;
                break;
              case "0A":
                obdData["Fuel Pressure"] = int.parse(parts[2], radix: 16) * 3.0;
                break;
              case "0C":
                if (parts.length >= 4) {
                  int a = int.parse(parts[2], radix: 16);
                  int b = int.parse(parts[3], radix: 16);
                  double rpmValue = ((a * 256) + b) / 4.0;
                  obdData["RPM"] = rpmValue;
                  _addLog("Parsed RPM: $rpmValue");
                } else {
                  _addLog("RPM response too short: $line");
                }
                break;
              case "0D":
                obdData["Speed"] = int.parse(parts[2], radix: 16).toDouble();
                break;
              case "0E":
                obdData["Timing Advance"] = (int.parse(parts[2], radix: 16) / 2.0) - 64.0;
                break;
              case "0F":
                obdData["Intake Temp"] = int.parse(parts[2], radix: 16) - 40.0;
                break;
              case "10":
                if (parts.length >= 4) {
                  int a = int.parse(parts[2], radix: 16);
                  int b = int.parse(parts[3], radix: 16);
                  obdData["MAF Air Flow"] = ((a * 256) + b) / 100.0;
                }
                break;
              case "11":
                obdData["Throttle Position"] = (int.parse(parts[2], radix: 16) * 100.0) / 255.0;
                break;
              case "42":
                if (parts.length >= 4) {
                  int a = int.parse(parts[2], radix: 16);
                  int b = int.parse(parts[3], radix: 16);
                  obdData["Battery Voltage"] = ((a * 256) + b) / 1000.0;
                }
                break;
            }
          } else if (mode == "43") {
            if (parts.length < 2) {
              _addLog("DTC response too short: $line");
              return;
            }

            int numDtcs = int.parse(parts[1], radix: 16);
            List<String> dtcs = [];

            for (int i = 0; i < numDtcs; i++) {
              int index = 2 + (i * 2);
              if (index + 1 >= parts.length) {
                _addLog("DTC response incomplete: $line");
                break;
              }

              String byte1 = parts[index];
              String byte2 = parts[index + 1];

              int firstByte = int.parse(byte1, radix: 16);
              int secondByte = int.parse(byte2, radix: 16);

              String dtcType;
              switch ((firstByte >> 6) & 0x03) {
                case 0:
                  dtcType = "P";
                  break;
                case 1:
                  dtcType = "C";
                  break;
                case 2:
                  dtcType = "B";
                  break;
                case 3:
                  dtcType = "U";
                  break;
                default:
                  dtcType = "P";
              }

              int dtcNumber = ((firstByte & 0x3F) << 8) + secondByte;
              String dtcCode = dtcNumber.toRadixString(16).padLeft(4, '0').toUpperCase();
              String dtc = "$dtcType$dtcCode";

              dtcs.add(dtc);
            }

            obdData["DTCs"] = dtcs;
            _addLog("Parsed DTCs: $dtcs");
          } else if (mode == "49" && parts[1] == "02") {
            if (parts.length < 4) {
              _addLog("VIN response too short: $line");
              return;
            }

            List<String> vinParts = parts.sublist(3);
            String vin = "";
            for (String hex in vinParts) {
              try {
                int charCode = int.parse(hex, radix: 16);
                vin += String.fromCharCode(charCode);
              } catch (e) {
                _addLog("Error parsing VIN hex $hex: $e");
              }
            }

            if (vin.length >= 17) {
              vin = vin.substring(0, 17);
            } else {
              _addLog("VIN too short (${vin.length} chars): $vin");
              vin = vin.padRight(17, " ");
            }

            obdData["VIN"] = vin;
            _addLog("Parsed VIN: $vin");
          }
        });

        widget.onDataUpdated(obdData);
      } catch (e) {
        _addLog("Parse error for Mode $mode: $e");
      }
    }
  }

  void _disconnect() {
    dataTimer?.cancel();
    connection?.dispose();
    setState(() {
      wasConnected = isConnected; // Store the previous connection state
      isConnected = false;
      connection = null;
      statusMessage = "Disconnected";
    });
    // Notify HomeScreen of disconnection
    widget.onConnectionStatusChanged(isConnected, wasConnected);
    _addLog("Disconnected");
    _startConnectionAttempts();
  }

  @override
  void dispose() {
    connectionTimer?.cancel();
    dataTimer?.cancel();
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}