import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_ui/screens/MapPage.dart';
import 'package:new_ui/screens/home_screen.dart';
import '../localized_text_widget.dart';
import 'profile_page.dart';
import 'razor_payment.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'wallet_provider.dart';
import 'add_money_page.dart';
import 'profile_page.dart';
import 'home_screen.dart';
import 'transaction_details_page.dart';
import 'notification_panel.dart';
import 'bottom_nav_bar.dart';

// Key for storing VIN in SharedPreferences
const String VIN_STORAGE_KEY = 'user_vehicle_vin';

class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}


class _WalletTabState extends State<WalletTab> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _balanceController;
  late Animation<double> _balanceAnimation;

  double _previousBalance = 0.0;
  int _selectedIconIndex = 2;
  DateTime? _selectedDate;
  String _selectedPaymentMethod = 'All';
  bool _showAllTransactions = false;
  String firstName = '';
  String vin = 'Not Set';
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // For deduction logic
  final String baseApiUrl = 'https://vianshah-demoservice.hf.space';
  bool isConnected = false;
  String connectionStatus = 'Not connected';
  Set<String> seenTimestamps = {}; // To track seen transactions
  List<Map<String, dynamic>> deductionLogs = [];
  Timer? _pollingTimer;
  bool isPolling = false;
  bool _isVinLoaded = false;

  // Store the listener function
  late VoidCallback _walletListener;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _balanceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _balanceAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _balanceController, curve: Curves.easeOut),
    );

    // Load VIN from SharedPreferences first, then fetch user data if needed
    _loadSavedVin().then((_) {
      if (vin == 'Not Set') {
        _fetchUserData();
      } else {
        // If VIN is already loaded, start polling directly
        _startPolling();
      }
    });

    // Set up Firebase Messaging for background deductions
    _setupFirebaseMessaging();
  }

  // Load VIN from SharedPreferences
  Future<void> _loadSavedVin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVin = prefs.getString(VIN_STORAGE_KEY);

      if (savedVin != null && savedVin.isNotEmpty) {
        setState(() {
          vin = savedVin;
          _isVinLoaded = true;
        });
        print("✅ Loaded VIN from local storage: $vin");

        // Start polling since we have the VIN
        _startPolling();
      }
    } catch (e) {
      print("❌ Error loading VIN from SharedPreferences: $e");
    }
  }

  // Save VIN to SharedPreferences
  Future<void> _saveVin(String vinNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(VIN_STORAGE_KEY, vinNumber);
      print("✅ Saved VIN to local storage: $vinNumber");
    } catch (e) {
      print("❌ Error saving VIN to SharedPreferences: $e");
    }
  }

  // Setup Firebase Messaging for background deductions
  void _setupFirebaseMessaging() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');

      // Get the token for this device
      String? token = await messaging.getToken();
      if (token != null) {
        _updateFcmToken(token);
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen(_updateFcmToken);

      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when user taps on notification and opens app
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  }

  // Update FCM token in Firestore
  Future<void> _updateFcmToken(String token) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print("✅ FCM token updated in Firestore");
      }
    } catch (e) {
      print("❌ Error updating FCM token: $e");
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print("📬 Received foreground message: ${message.data}");

    // Check if it's a deduction notification
    if (message.data.containsKey('type') &&
        message.data['type'] == 'deduction' &&
        message.data.containsKey('amount')) {

      // Process the deduction
      double amount = double.tryParse(message.data['amount']) ?? 0.0;
      if (amount > 0) {
        _processDeduction(amount, message.data['timestamp'] ?? DateTime.now().toIso8601String());
      }
    }
  }

  // Handle when user taps on notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    print("📱 User tapped on notification: ${message.data}");

    // You can navigate to a specific screen if needed
    // For example, show transaction details
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isPolling) {
        _checkForUpdates();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    _updateBalanceAnimation(wallet.balance);

    // Define the listener and store it
    _walletListener = () {
      _updateBalanceAnimation(wallet.balance);
    };
    wallet.addListener(_walletListener);
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentReference userDocRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

      userDocRef.snapshots().listen((DocumentSnapshot userData) {
        if (userData.exists && userData.data() != null) {
          var data = userData.data() as Map<String, dynamic>;

          final newBalance = (data['balance'] ?? 0.0).toDouble();
          final wallet = Provider.of<WalletProvider>(context, listen: false);

          setState(() {
            firstName = data['firstName'] ?? 'Name';

            // Only update VIN if it's not already loaded
            if (!_isVinLoaded) {
              // Retrieve VIN number from Firebase
              String newVin = data['vehicle']?['vin'] ?? 'Not Set';
              if (newVin != 'Not Set' && newVin != vin) {
                vin = newVin;
                _isVinLoaded = true;

                // Save VIN to SharedPreferences for future use
                _saveVin(vin);

                // Start polling since we now have the VIN
                _startPolling();

                // Fetch initial deduction logs
                _fetchInitialDeductionLogs();
              }
            }
          });

          wallet.updateBalance(newBalance);
        }
      });
    } catch (e) {
      print("❌ Error fetching user data: $e");
    }
  }

  // Process a deduction (can be called from foreground or background)
  void _processDeduction(double amount, String timestamp) async {
    if (seenTimestamps.contains(timestamp)) {
      print("🔄 Skipping already processed deduction: $timestamp");
      return;
    }

    try {
      final wallet = Provider.of<WalletProvider>(context, listen: false);

      // Create a transaction for the deduction
      final deductionTransaction = WalletTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        date: DateTime.now(),
        paymentMethod: 'Paid',
        description: 'Automatic deduction',
        isDeduction: true,
        status: 'Completed',
        transactionId: 'deduct-${DateTime.now().millisecondsSinceEpoch}',
      );

      // Add the transaction to the wallet provider
      wallet.addTransaction(deductionTransaction);

      // Subtract money from balance
      wallet.subtractMoney(amount, context);

      // Add notification for the deduction
      wallet.addNotification(
        'Automatic Deduction',
        'Amount ₹${amount.toStringAsFixed(2)} has been deducted from your wallet.',
        DateTime.now(),
      );

      // Add to seen timestamps
      seenTimestamps.add(timestamp);

      print("💰 Processed deduction: ₹$amount at $timestamp");
    } catch (e) {
      print("❌ Error processing deduction: $e");
    }
  }

  // Fetch initial deduction logs
  Future<void> _fetchInitialDeductionLogs() async {
    if (vin == 'Not Set') return;

    try {
      final response = await http.get(
        Uri.parse('$baseApiUrl/deduct-data-log'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> logs = json.decode(response.body);

        // Filter logs for this VIN and convert to list
        List<Map<String, dynamic>> vinLogs = [];
        logs.forEach((key, value) {
          Map<String, dynamic> log = Map<String, dynamic>.from(value as Map);
          if (log['vin'] == vin) {
            vinLogs.add(log);
            seenTimestamps.add(log['timestamp'] as String);
          }
        });

        setState(() {
          deductionLogs = vinLogs;
          isConnected = true;
          connectionStatus = 'Connected to room: $vin';
        });

        print("📋 Loaded ${vinLogs.length} initial deduction logs");
      } else {
        setState(() {
          isConnected = false;
          connectionStatus = 'Failed to fetch logs: ${response.statusCode}';
        });
      }
    } catch (e) {
      print("❌ Error fetching initial deduction logs: $e");
      setState(() {
        isConnected = false;
        connectionStatus = 'Connection error: $e';
      });
    }
  }

  // Check for deduction updates from API
  Future<void> _checkForUpdates() async {
    if (isPolling || vin == 'Not Set') return; // Prevent concurrent polling or if VIN is not set

    setState(() {
      isPolling = true;
    });

    try {
      // First try to get latest deduction
      final response = await http.get(
        Uri.parse('$baseApiUrl/get-latest-deduction/$vin'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      // Update connection status
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected to room: $vin';
      });

      if (response.statusCode == 200) {
        // We have a new deduction log
        final Map<String, dynamic> log = json.decode(response.body);

        // Check if we've already seen this deduction
        if (!seenTimestamps.contains(log['timestamp'] as String)) {
          double amount = (log['amount'] as num).toDouble();
          _processDeduction(amount, log['timestamp'] as String);

          // Add to deduction logs
          Map<String, dynamic> deductionLog = Map<String, dynamic>.from(log);
          deductionLog['isDeduction'] = true;
          deductionLogs.add(deductionLog);
        }
      } else if (response.statusCode == 204) {
        // No new content, which is fine - just continue polling
      } else {
        // Fallback to the old method if the new endpoint fails
        await _fallbackCheckForUpdates();
      }
    } catch (e) {
      print("❌ Error checking for updates: $e");
      // Try fallback method
      await _fallbackCheckForUpdates();
    } finally {
      setState(() {
        isPolling = false;
      });
    }
  }

  // Fallback method using the old API endpoint
  Future<void> _fallbackCheckForUpdates() async {
    try {
      final response = await http.get(Uri.parse('$baseApiUrl/deduct-data-log'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> logs = json.decode(response.body);

        List<Map<String, dynamic>> newLogs = logs.values
            .map((log) => Map<String, dynamic>.from(log))
            .where((log) =>
        log['vin'] == vin && !seenTimestamps.contains(log['timestamp']))
            .toList();

        if (newLogs.isNotEmpty) {
          for (var log in newLogs) {
            double amount = (log['amount'] as num).toDouble();
            _processDeduction(amount, log['timestamp'] as String);
            deductionLogs.add(log);
          }
        }

        setState(() {
          isConnected = true;
          connectionStatus = 'Connected to room: $vin';
        });
      } else {
        setState(() {
          isConnected = false;
          connectionStatus = 'Connection failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      print("❌ Error in fallback check for updates: $e");
      setState(() {
        isConnected = false;
        connectionStatus = 'Connection error: $e';
      });
    }
  }

  void _updateBalanceAnimation(double newBalance) {
    if (!mounted) return; // Check if widget is still mounted
    _previousBalance = _balanceAnimation.value;
    _balanceAnimation = Tween<double>(
      begin: _previousBalance,
      end: newBalance,
    ).animate(
      CurvedAnimation(parent: _balanceController, curve: Curves.easeOut),
    );
    // Only call forward if the widget is still mounted
    if (mounted) {
      _balanceController.forward(from: 0.0);
    }
  }

  IconData _getPaymentIcon(String paymentMethod, bool isDeduction) {
    if (isDeduction) {
      return Icons.confirmation_num;
    }
    switch (paymentMethod) {
      case 'Added to wallet':
        return Icons.credit_score;
      case 'Paid':
        return Icons.payment;
      default:
        return Icons.credit_score;
    }
  }

  Color _getPaymentIconColor(String paymentMethod, bool isDeduction) {
    if (isDeduction) {
      return Colors.deepOrange.shade300;
    }
    switch (paymentMethod) {
      case 'Added to wallet':
        return Colors.lightGreen;
      case 'Paid':
        return Colors.deepOrange.shade300;
      default:
        return Colors.lightGreen;
    }
  }

  void _navigateToTransactionDetails(WalletTransaction transaction) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return TransactionDetailsPage(transaction: transaction);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  List<WalletTransaction> _getFilteredTransactions(List<WalletTransaction> transactions) {
    final filteredList = transactions.where((transaction) {
      final matchesDate = _selectedDate == null ||
          _normalizeDate(transaction.date) == _normalizeDate(_selectedDate!);

      final matchesPaymentMethod = _selectedPaymentMethod == 'All' ||
          (_selectedPaymentMethod == 'Credit' &&
              transaction.description == 'Added to wallet') ||
          (_selectedPaymentMethod == 'Debit' &&
              transaction.paymentMethod == 'Paid');

      final isValidTransactionType =
          transaction.description == 'Added to wallet' ||
              transaction.paymentMethod == 'Paid';

      return matchesDate && matchesPaymentMethod && isValidTransactionType;
    }).toList();

    if (_showAllTransactions) {
      return filteredList;
    } else {
      return filteredList.take(6).toList();
    }
  }

  DateTime _normalizeDate(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  void _showAddMoneyDialog() {
    _mobileNumberController.clear();
    _amountController.clear();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LocalizedText(
                      text: 'Add Money',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LocalizedText(
                  text:  'Mobile Number',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Enter 10 digit mobile number',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(Icons.phone, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                LocalizedText(
                  text: 'Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Enter amount',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_mobileNumberController.text.isEmpty ||
                          _mobileNumberController.text.length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: LocalizedText(
                              text: 'Please enter a valid 10-digit mobile number',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (_amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:LocalizedText(
                              text: 'Please enter an amount',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final amount = double.tryParse(_amountController.text);
                      final number = int.tryParse(_mobileNumberController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:LocalizedText(
                              text: 'Please enter a valid amount',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final wallet = Provider.of<WalletProvider>(context, listen: false);
                      Navigator.pop(context);
                      wallet.addMoneyWithRazorpay(amount,number!);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: LocalizedText(
                      text: 'Submit',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showDatePickerDialog() {
    DateTime tempSelectedDate = _selectedDate ?? DateTime.now();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                width: MediaQuery.of(context).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LocalizedText(
                          text:  'Select Date',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 300,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.black,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: tempSelectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          onDateChanged: (DateTime newDate) {
                            setDialogState(() {
                              tempSelectedDate = newDate;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = tempSelectedDate;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child:LocalizedText(
                          text: 'Done',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,

                child: Container(
                  height: 230,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 41, left: 14, right: 20),
                            child: Row(
                              children: [
                                LocalizedText(
                                  text: "My Wallet",
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.date_range_rounded,
                                      color: Colors.white),
                                  onPressed: _showDatePickerDialog,
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => _buildPaymentMethodFilter(),
                                    );
                                  },
                                ),
                                // Stack(
                                //   children: [
                                //     IconButton(
                                //       icon: Icon(
                                //         walletProvider.hasUnreadNotifications
                                //             ? Icons.notifications_active // Filled bell icon
                                //             : Icons.notifications_none, // Unfilled bell icon
                                //         size: 28,
                                //         color: Colors.white,
                                //       ),
                                //       onPressed: () {
                                //         Navigator.push(
                                //           context,
                                //           MaterialPageRoute(
                                //             builder: (context) => NotificationsPage1(
                                //               previousPage: 'Wallet',
                                //               currentIndex: _selectedIconIndex,
                                //             ),
                                //           ),
                                //         ).then((_) {
                                //           // Mark notifications as read when returning from NotificationsPage
                                //           walletProvider.markNotificationsAsRead();
                                //         });
                                //       },
                                //     ),
                                //     if (walletProvider.hasUnreadNotifications)
                                //       Positioned(
                                //         right: 6,
                                //         top: 6,
                                //         child: Container(
                                //           padding: const EdgeInsets.all(4),
                                //           decoration: const BoxDecoration(
                                //             color: Colors.red,
                                //             shape: BoxShape.circle,
                                //           ),
                                //           child: Text(
                                //             walletProvider.unreadNotificationCount.toString(),
                                //             style: const TextStyle(
                                //               fontSize: 12,
                                //               color: Colors.white,
                                //             ),
                                //           ),
                                //         ),
                                //       ),
                                //   ],
                                // ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: Consumer<WalletProvider>(
                              builder: (context, wallet, child) {
                                return Material(
                                  elevation: 18.0,
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 223,
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF000000),
                                          const Color(0xFF607D8B),
                                          const Color(0xFF000000),
                                        ],
                                        stops: [0.4, 0.6, 0.85],
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all( // ✅ Light teal border added
                                        color: Colors.blueGrey.withOpacity(0.3), // Light teal color
                                        width: 2, // Adjust thickness
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.account_balance_wallet_outlined,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                            const SizedBox(width: 8),
                                            LocalizedText(
                                              text: 'Available Balance',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 31),
                                        AnimatedBuilder(
                                          animation: _balanceAnimation,
                                          builder: (context, child) {
                                            return Text(
                                              '₹ ${_balanceAnimation.value.toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 50,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            LocalizedText(
                                              text: "$firstName 's Wallet",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                // GestureDetector(
                                                //   onTap: () async {
                                                //     final subtractedAmount = await Navigator.of(context).push(
                                                //       _createRoute(const AddMoneyPage()),
                                                //     );
                                                //     if (subtractedAmount != null && subtractedAmount is double) {
                                                //       final wallet = Provider.of<WalletProvider>(context, listen: false);
                                                //       wallet.subtractMoney(subtractedAmount, context);
                                                //     }
                                                //   },
                                                //   child: Container(
                                                //     padding: const EdgeInsets.all(6),
                                                //     decoration: BoxDecoration(
                                                //       border: Border.all(color: Colors.white),
                                                //       shape: BoxShape.circle,
                                                //     ),
                                                //     child: const Icon(
                                                //       Icons.remove,
                                                //       color: Colors.white,
                                                //       size: 18,
                                                //     ),
                                                //   ),
                                                // ),
                                                const SizedBox(width: 10),
                                                GestureDetector(
                                                  onTap: () {
                                                    _showAddMoneyDialog();
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Colors.white),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.add,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: Center(
                              child: LocalizedText(
                                text:"Your recent transactions",
                                style: GoogleFonts.poppins(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0),
                            child: Consumer<WalletProvider>(
                              builder: (context, wallet, child) {
                                final filteredTransactions = wallet.transactions.where((transaction) {
                                  final matchesDate = _selectedDate == null ||
                                      _normalizeDate(transaction.date) == _normalizeDate(_selectedDate!);
                                  final matchesPaymentMethod = _selectedPaymentMethod == 'All' ||
                                      (_selectedPaymentMethod == 'Credit' &&
                                          transaction.paymentMethod == 'Razorpay') ||
                                      (_selectedPaymentMethod == 'Debit' &&
                                          transaction.paymentMethod == 'Paid');
                                  final isValidTransactionType =
                                      transaction.paymentMethod == 'Razorpay' ||
                                          transaction.paymentMethod == 'Paid';
                                  return matchesDate && matchesPaymentMethod && isValidTransactionType;
                                }).toList();

                                // Add debug prints
                                print('Total transactions: ${wallet.transactions.length}');
                                print('Total filtered transactions: ${filteredTransactions.length}');
                                print('Show all transactions: $_showAllTransactions');

                                final displayTransactions = _showAllTransactions
                                    ? filteredTransactions
                                    : filteredTransactions.take(6).toList();

                                return Column(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.5,
                                      child: SingleChildScrollView(
                                        child: displayTransactions.isEmpty
                                            ? Center(
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 55),
                                              Image.asset(
                                                'assets/images/no_payments.jpg',
                                                height: 200,
                                                width: 200,
                                              ),
                                              const SizedBox(height: 20),
                                              LocalizedText(
                                                text: 'No Transactions Yet!',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                            : Column(
                                          children: [
                                            ...displayTransactions.map((transaction) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 16),
                                                child: GestureDetector(
                                                  onTap: () => _navigateToTransactionDetails(transaction),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 24,
                                                        backgroundColor: Colors.grey.withOpacity(0.00),
                                                        child: Icon(
                                                          _getPaymentIcon(
                                                              transaction.paymentMethod,
                                                              transaction.isDeduction),
                                                          color: _getPaymentIconColor(
                                                              transaction.paymentMethod,
                                                              transaction.isDeduction),
                                                          size: 28,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            LocalizedText(
                                                              text: transaction.paymentMethod == 'Razorpay'
                                                                  ? "Credited to $firstName wallet"
                                                                  : transaction.description ?? 'Unknown',
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.black,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              transaction.date
                                                                  .toLocal()
                                                                  .toString()
                                                                  .split('.')[0] ??
                                                                  'Unknown',
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 13,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Text(
                                                            transaction.isDeduction
                                                                ? '- ₹${transaction.amount.toStringAsFixed(2)}'
                                                                : '+ ₹${transaction.amount.toStringAsFixed(2)}',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              color: transaction.isDeduction
                                                                  ? Colors.deepOrange.shade300
                                                                  : Colors.lightGreen,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            if (filteredTransactions.length > 6)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                                child: TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _showAllTransactions = !_showAllTransactions;
                                                    });
                                                  },
                                                  child:LocalizedText(
                                                    text:  _showAllTransactions ? "Show less" : "View more",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.blue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              BottomNavBar(selectedIndex: _selectedIconIndex)
            ],
          ),
        );
      },
    );
  }


  Widget _buildPaymentMethodFilter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.lightBlueAccent,
            ),
            title: LocalizedText(
                text:'All', style: GoogleFonts.poppins()),
            onTap: () {
              setState(() {
                _selectedPaymentMethod = 'All';
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.credit_score,
              color: Colors.lightGreen,
            ),
            title: LocalizedText(
              text: 'Credit', style: GoogleFonts.poppins(),
            ),
            onTap: () {
              setState(() {
                _selectedPaymentMethod = 'Credit';
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.confirmation_num,
              color: Colors.deepOrange,
            ),
            title: Text('Debit', style: GoogleFonts.poppins()),
            onTap: () {
              setState(() {
                _selectedPaymentMethod = 'Debit';
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final opacityAnimation = animation.drive(tween);
        return FadeTransition(opacity: opacityAnimation, child: child);
      },
    );
  }

  @override
  void dispose() {
    // Remove the listener before disposing controllers
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    wallet.removeListener(_walletListener);

    _controller.dispose();
    _balanceController.dispose();
    _mobileNumberController.dispose();
    _amountController.dispose();
    _pollingTimer?.cancel(); // Cancel the polling timer
    super.dispose();
  }
}

// This function needs to be defined at the top level (outside any class)
// to handle background messages when the app is closed
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This will be called when a message is received while the app is in the background
  print("Handling background message: ${message.data}");

  // You can't directly update UI or use providers here
  // Instead, store the deduction info in SharedPreferences to be processed when app opens

  if (message.data.containsKey('type') &&
      message.data['type'] == 'deduction' &&
      message.data.containsKey('amount') &&
      message.data.containsKey('timestamp')) {

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing pending deductions or create new list
      List<String> pendingDeductions = prefs.getStringList('pending_deductions') ?? [];

      // Add new deduction as JSON string
      Map<String, dynamic> deductionData = {
        'amount': message.data['amount'],
        'timestamp': message.data['timestamp'],
      };

      pendingDeductions.add(jsonEncode(deductionData));

      // Save updated list
      await prefs.setStringList('pending_deductions', pendingDeductions);

      print("✅ Saved pending deduction to be processed when app opens");
    } catch (e) {
      print("❌ Error saving pending deduction: $e");
    }
  }
}