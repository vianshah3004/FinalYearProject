import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_ui/ui/screens/home/dashboard/transaction_details_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../providers/wallet_provider.dart';
import '../../../../widgets/localized_text_widget.dart';
import 'package:new_ui/ui/screens/home/bottom_nav_bar.dart';


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

  final String baseApiUrl = 'https://vianshah-demoservice.hf.space';
  bool isConnected = false;
  String connectionStatus = 'Not connected';
  Set<String> seenTransactionIds = {};
  List<Map<String, dynamic>> deductionLogs = [];
  Timer? _pollingTimer;
  bool isPolling = false;
  bool _isVinLoaded = false;

  late VoidCallback _walletListener;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

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

    _loadSavedVin().then((_) {
      _fetchUserData();
      if (vin != 'Not Set') {
        _startPolling();
      }
    });

    _setupFirebaseMessaging();

    // Initial refresh of transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTransactions();
    });
  }

  Future<void> _refreshTransactions() async {
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    await wallet.refreshTransactions();
    setState(() {
      // Force UI update after refreshing transactions
    });
    return Future.value();
  }

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
        _startPolling();
      }
    } catch (e) {
      print("❌ Error loading VIN from SharedPreferences: $e");
    }
  }

  Future<void> _saveVin(String vinNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(VIN_STORAGE_KEY, vinNumber);
      print("✅ Saved VIN to local storage: $vinNumber");
    } catch (e) {
      print("❌ Error saving VIN to SharedPreferences: $e");
    }
  }

  void _setupFirebaseMessaging() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
      String? token = await messaging.getToken();
      if (token != null) _updateFcmToken(token);

      messaging.onTokenRefresh.listen(_updateFcmToken);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> _updateFcmToken(String token) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token, 'lastTokenUpdate': FieldValue.serverTimestamp()});
        print("✅ FCM token updated in Firestore");
      }
    } catch (e) {
      print("❌ Error updating FCM token: $e");
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print("📬 Received foreground message: ${message.data}");
    if (message.data['type'] == 'deduction' && message.data['amount'] != null && message.data['timestamp'] != null) {
      double amount = double.tryParse(message.data['amount']) ?? 0.0;
      String timestamp = message.data['timestamp'] ?? DateTime.now().toIso8601String();
      String transactionId = 'deduction-${timestamp.hashCode}';
      _processDeduction(amount, timestamp, transactionId, source: 'firebase');
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print("📱 User tapped on notification: ${message.data}");
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isPolling) _checkForUpdates();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    _updateBalanceAnimation(wallet.balance);

    _walletListener = () {
      if (mounted) {
        setState(() {});
      }
      _updateBalanceAnimation(wallet.balance);
    };
    wallet.addListener(_walletListener);
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No authenticated user found");
        setState(() {
          firstName = 'Guest';
        });
        return;
      }

      print("Fetching user data for UID: ${user.uid}");
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      userDocRef.snapshots().listen((DocumentSnapshot userData) {
        if (userData.exists && userData.data() != null) {
          var data = userData.data() as Map<String, dynamic>;
          print("Received data: $data");
          final newBalance = (data['balance'] ?? 0.0).toDouble();
          final wallet = Provider.of<WalletProvider>(context, listen: false);

          setState(() {
            firstName = data['firstName'] ?? 'Name';
            if (!_isVinLoaded) {
              String newVin = data['vehicle']?['vin'] ?? 'Not Set';
              if (newVin != 'Not Set' && newVin != vin) {
                vin = newVin;
                _isVinLoaded = true;
                _saveVin(vin);
                _startPolling();
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

  void _processDeduction(double amount, String timestamp, String transactionId, {String source = 'api'}) {
    if (seenTransactionIds.contains(transactionId)) {
      print("🔄 Skipping already processed deduction: $transactionId (from $source)");
      return;
    }

    try {
      final wallet = Provider.of<WalletProvider>(context, listen: false);

      final deductionTransaction = WalletTransaction(
        id: transactionId,
        amount: amount,
        date: DateTime.parse(timestamp),
        paymentMethod: 'Paid',
        description: 'National Highways Authority of India (NHAI)',
        isDeduction: true,
        status: 'Completed',
        transactionId: transactionId,
      );

      if (!wallet.transactions.any((t) => t.id == transactionId)) {
        wallet.addTransaction(deductionTransaction);
        wallet.subtractMoney(amount, context);

        wallet.addNotification(
          'NHAI Deduction',
          'Amount ₹${amount.toStringAsFixed(2)} has been deducted by National Highways Authority of India (NHAI).',
          DateTime.now(),
          transactionId: transactionId,
        );

        seenTransactionIds.add(transactionId);
        print("💰 Processed deduction: ₹$amount with ID $transactionId (from $source)");

        // _syncTransactionToFirebase(deductionTransaction);

        // Force UI update
        setState(() {});
      }
    } catch (e) {
      print("❌ Error processing deduction: $e");
    }
  }

  Future<void> _syncTransactionToFirebase(WalletTransaction transaction) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(transaction.id)
            .set({
          'id': transaction.id,
          'amount': transaction.amount,
          'date': transaction.date.toIso8601String(),
          'paymentMethod': transaction.paymentMethod,
          'description': transaction.description,
          'isDeduction': transaction.isDeduction,
          'status': transaction.status,
          'transactionId': transaction.id,
        });
      }
    } catch (e) {
      print("❌ Error syncing transaction to Firebase: $e");
    }
  }

  Future<void> _fetchInitialDeductionLogs() async {
    if (vin == 'Not Set') return;

    try {
      final response = await http.get(
        Uri.parse('$baseApiUrl/deduct-data-log'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> logs = json.decode(response.body);
        List<Map<String, dynamic>> vinLogs = logs.values
            .map((log) => Map<String, dynamic>.from(log))
            .where((log) => log['vin'] == vin && !seenTransactionIds.contains('deduction-${log['timestamp'].hashCode}'))
            .toList();

        setState(() {
          deductionLogs = vinLogs;
          isConnected = true;
          connectionStatus = 'Connected to room: $vin';
        });

        for (var log in vinLogs) {
          double amount = (log['amount'] as num).toDouble();
          String transactionId = 'deduction-${log['timestamp'].hashCode}';
          _processDeduction(amount, log['timestamp'] as String, transactionId, source: 'initial');
        }
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

  Future<void> _checkForUpdates() async {
    if (isPolling || vin == 'Not Set') return;

    setState(() => isPolling = true);

    try {
      final response = await http.get(
        Uri.parse('$baseApiUrl/get-latest-deduction/$vin'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      setState(() {
        isConnected = true;
        connectionStatus = 'Connected to room: $vin';
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> log = json.decode(response.body);
        String transactionId = 'deduction-${log['timestamp'].hashCode}';
        if (!seenTransactionIds.contains(transactionId)) {
          double amount = (log['amount'] as num).toDouble();
          _processDeduction(amount, log['timestamp'] as String, transactionId, source: 'polling');
          deductionLogs.add(log);
        }
      } else if (response.statusCode == 204) {
        // No new content
      } else {
        await _fallbackCheckForUpdates();
      }
    } catch (e) {
      print("❌ Error checking for updates: $e");
      await _fallbackCheckForUpdates();
    } finally {
      setState(() => isPolling = false);
    }
  }

  Future<void> _fallbackCheckForUpdates() async {
    try {
      final response = await http.get(Uri.parse('$baseApiUrl/deduct-data-log'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> logs = json.decode(response.body);
        List<Map<String, dynamic>> newLogs = logs.values
            .map((log) => Map<String, dynamic>.from(log))
            .where((log) => log['vin'] == vin && !seenTransactionIds.contains('deduction-${log['timestamp'].hashCode}'))
            .toList();

        for (var log in newLogs) {
          double amount = (log['amount'] as num).toDouble();
          String transactionId = 'deduction-${log['timestamp'].hashCode}';
          _processDeduction(amount, log['timestamp'] as String, transactionId, source: 'fallback');
          deductionLogs.add(log);
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
    if (!mounted) return;
    _previousBalance = _balanceAnimation.value;
    _balanceAnimation = Tween<double>(begin: _previousBalance, end: newBalance).animate(
      CurvedAnimation(parent: _balanceController, curve: Curves.easeOut),
    );
    if (mounted) _balanceController.forward(from: 0.0);
  }

  IconData _getPaymentIcon(String paymentMethod, bool isDeduction) {
    if (isDeduction) return Icons.confirmation_num;
    switch (paymentMethod) {
      case 'Razorpay':
        return Icons.credit_score;
      case 'Paid':
        return Icons.payment;
      default:
        return Icons.credit_score;
    }
  }

  Color _getPaymentIconColor(String paymentMethod, bool isDeduction) {
    if (isDeduction) return Colors.deepOrange.shade300;
    switch (paymentMethod) {
      case 'Razorpay':
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
        pageBuilder: (context, animation, secondaryAnimation) => TransactionDetailsPage(transaction: transaction),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  List<WalletTransaction> _getFilteredTransactions(List<WalletTransaction> transactions) {
    // Create a new list to avoid reference issues
    List<WalletTransaction> filteredList = List.from(transactions);

    return filteredList.where((transaction) {
      final matchesDate = _selectedDate == null || _normalizeDate(transaction.date) == _normalizeDate(_selectedDate!);
      final matchesPaymentMethod = _selectedPaymentMethod == 'All' ||
          (_selectedPaymentMethod == 'Credit' && transaction.paymentMethod == 'Razorpay') ||
          (_selectedPaymentMethod == 'Debit' && transaction.paymentMethod == 'Paid');
      final isValidTransactionType = transaction.paymentMethod == 'Razorpay' || transaction.paymentMethod == 'Paid';
      return matchesDate && matchesPaymentMethod && isValidTransactionType;
    }).toList().take(_showAllTransactions ? transactions.length : 6).toList();
  }

  DateTime _normalizeDate(DateTime dateTime) => DateTime(dateTime.year, dateTime.month, dateTime.day);

  void _showAddMoneyDialog() {
    _mobileNumberController.clear();
    _amountController.clear();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
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
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50)),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                LocalizedText(text: 'Mobile Number', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    hintText: 'Enter 10 digit mobile number',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                LocalizedText(text: 'Amount (Min-500 and Max-10000)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    hintText: 'Enter amount',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_mobileNumberController.text.length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LocalizedText(text: 'Please enter a valid 10-digit mobile number', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (_amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LocalizedText(text: 'Please enter an amount', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final amount = double.tryParse(_amountController.text) ?? 0.0;
                      final number = int.tryParse(_mobileNumberController.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LocalizedText(text: 'Please enter a valid amount', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      if (amount < 500) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LocalizedText(text: 'Minimum amount to add is ₹500', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (amount > 10000) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LocalizedText(text: 'Maximum amount to add is ₹10000', style: GoogleFonts.poppins()), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final wallet = Provider.of<WalletProvider>(context, listen: false);
                      Navigator.pop(context);
                      await wallet.addMoneyWithRazorpay(amount, number);

                      // Force refresh transactions after adding money
                      _refreshTransactions();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: LocalizedText(text: 'Submit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
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
                        LocalizedText(text: 'Select Date', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 300,
                      child: Theme(
                        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.black)),
                        child: CalendarDatePicker(
                          initialDate: tempSelectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          onDateChanged: (DateTime newDate) => setDialogState(() => tempSelectedDate = newDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedDate = tempSelectedDate);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
                        child: LocalizedText(text: 'Done', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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
          body: RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshTransactions,
            child: Stack(
              children: [
                Positioned(top: 0, left: 0, right: 0, child: Container(height: 230, decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25))))),
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 41, left: 14, right: 20),
                              child: Row(
                                children: [
                                  LocalizedText(text: "My Wallet", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const Spacer(),
                                  IconButton(icon: const Icon(Icons.date_range_rounded, color: Colors.white), onPressed: _showDatePickerDialog),
                                  IconButton(icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white), onPressed: () => showModalBottomSheet(context: context, builder: (context) => _buildPaymentMethodFilter())),
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
                                          colors: [const Color(0xFF000000), const Color(0xFF607D8B), const Color(0xFF000000)],
                                          stops: [0.4, 0.6, 0.85],
                                        ),
                                        borderRadius: BorderRadius.circular(20.0),
                                        border: Border.all(color: Colors.blueGrey.withOpacity(0.3), width: 2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
                                              const SizedBox(width: 8),
                                              LocalizedText(text: 'Available Balance', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                          const SizedBox(height: 31),
                                          AnimatedBuilder(
                                            animation: _balanceAnimation,
                                            builder: (context, child) => Text('₹ ${_balanceAnimation.value.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              LocalizedText(text: "${wallet.userName}'s Wallet", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20)),
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _showAddMoneyDialog(),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(border: Border.all(color: Colors.white), shape: BoxShape.circle),
                                                      child: const Icon(Icons.add, color: Colors.white, size: 18),
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
                                child: LocalizedText(text: "Your recent transactions", style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w600, color: Colors.black)),
                              ),
                            ),
                            const SizedBox(height: 22.0),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28.0),
                              child: Consumer<WalletProvider>(
                                key: ValueKey('transactions-consumer-${walletProvider.transactions.length}'),
                                builder: (context, wallet, child) {
                                  final filteredTransactions = _getFilteredTransactions(wallet.transactions);
                                  final displayTransactions = filteredTransactions.take(_showAllTransactions ? wallet.transactions.length : 6).toList();

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
                                                Image.asset('assets/images/no_payments.jpg', height: 200, width: 200),
                                                const SizedBox(height: 20),
                                                LocalizedText(text: 'No Transactions Yet!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                                              ],
                                            ),
                                          )
                                              : Column(
                                            children: [
                                              ...displayTransactions.map((transaction) => Padding(
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
                                                          _getPaymentIcon(transaction.paymentMethod, transaction.isDeduction),
                                                          color: _getPaymentIconColor(transaction.paymentMethod, transaction.isDeduction),
                                                          size: 28,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            LocalizedText(
                                                              text: transaction.isDeduction
                                                                  ? 'National Highways Authority of India (NHAI)'
                                                                  : (transaction.paymentMethod == 'Razorpay'
                                                                  ? "Credited to ${wallet.userName}'s wallet"
                                                                  : transaction.description),
                                                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              transaction.date.toLocal().toString().split('.')[0],
                                                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Text(
                                                            transaction.isDeduction ? '- ₹${transaction.amount.toStringAsFixed(2)}' : '+ ₹${transaction.amount.toStringAsFixed(2)}',
                                                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: transaction.isDeduction ? Colors.deepOrange.shade300 : Colors.lightGreen),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )).toList(),
                                              if (filteredTransactions.length > 6)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                                  child: TextButton(
                                                    onPressed: () => setState(() => _showAllTransactions = !_showAllTransactions),
                                                    child: LocalizedText(
                                                        text: _showAllTransactions ? "Show less" : "View more",
                                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue, decoration: TextDecoration.underline)),
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
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodFilter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.lightBlueAccent),
            title: LocalizedText(text: 'All', style: GoogleFonts.poppins()),
            onTap: () {
              setState(() => _selectedPaymentMethod = 'All');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_score, color: Colors.lightGreen),
            title: LocalizedText(text: 'Credit', style: GoogleFonts.poppins()),
            onTap: () {
              setState(() => _selectedPaymentMethod = 'Credit');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.confirmation_num, color: Colors.deepOrange),
            title: LocalizedText(text: 'Debit', style: GoogleFonts.poppins()),
            onTap: () {
              setState(() => _selectedPaymentMethod = 'Debit');
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
        return FadeTransition(opacity: animation.drive(tween), child: child);
      },
    );
  }

  @override
  void dispose() {
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    wallet.removeListener(_walletListener);
    _controller.dispose();
    _balanceController.dispose();
    _mobileNumberController.dispose();
    _amountController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling background message: ${message.data}");
  if (message.data['type'] == 'deduction' && message.data['amount'] != null && message.data['timestamp'] != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingDeductions = prefs.getStringList('pending_deductions') ?? [];
      String transactionId = 'deduction-${message.data['timestamp'].hashCode}';
      if (!pendingDeductions.any((deduction) => jsonDecode(deduction)['transactionId'] == transactionId)) {
        Map<String, dynamic> deductionData = {
          'amount': message.data['amount'],
          'timestamp': message.data['timestamp'],
          'transactionId': transactionId,
        };
        pendingDeductions.add(jsonEncode(deductionData));
        await prefs.setStringList('pending_deductions', pendingDeductions);
        print("✅ Saved pending deduction: $transactionId");
      } else {
        print("🔄 Skipping duplicate pending deduction: $transactionId");
      }
    } catch (e) {
      print("❌ Error saving pending deduction: $e");
    }
  }
}