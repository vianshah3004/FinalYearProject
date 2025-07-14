import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../ui/screens/auth/local_auth_verify.dart'; // For Platform checks

class WalletTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String description;
  final bool isDeduction;
  final String status;
  final String transactionId;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.description,
    this.isDeduction = false,
    required this.status,
    required this.transactionId,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String dateString = data['date'] ?? DateTime.now().toIso8601String();
    DateTime transactionDate;

    try {
      if (data['date'] is Timestamp) {
        transactionDate = (data['date'] as Timestamp).toDate();
      } else {
        transactionDate = DateTime.parse(dateString);
      }
    } catch (e) {
      print("Error parsing date: $e");
      transactionDate = DateTime.now();
    }

    return WalletTransaction(
      id: data['id'] ?? doc.id,
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: transactionDate,
      paymentMethod: data['paymentMethod'] ?? (data['isDeduction'] ? 'Paid' : 'Razorpay'),
      description: data['description'] ?? '',
      isDeduction: data['isDeduction'] ?? false,
      status: data['status'] ?? 'Completed',
      transactionId: data['transactionId'] ?? data['id'] ?? doc.id,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'description': description,
      'isDeduction': isDeduction,
      'status': status,
      'transactionId': transactionId,
    };
  }
}

class WalletProvider with ChangeNotifier {
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  bool _hasUnreadNotifications = false;
  String _userName = '';
  String _emailuser = '';
  late Razorpay _razorpay;
  int _unreadNotificationCount = 0;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final LocalAuthHelper _localAuthHelper = LocalAuthHelper();
  final String groupKey = 'payment_group';
  final String paymentChannelId = 'payment_channel';

  Function? onTransactionMade;

  WalletProvider() {
    _initializeRazorpay();
    _initializeNotifications();
    _fetchInitialData();
    _fetchTransactions();
    _fetchUnreadNotificationCount();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  void _initializeNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      await _requestNotificationPermission();
    }
  }

  Future<void> _showPaymentSuccessNotification(double amount) async {
    String formattedDate = "${DateTime.now().day}-${_getMonth(DateTime.now().month)}-${DateTime.now().year % 100}";
    String notificationMessage = "An amount of ₹$amount is credited into your Toll Seva account on $formattedDate.\n\nYour current balance is ₹$_balance.\n\nToll Seva";
    BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      notificationMessage,
      contentTitle: "PAYMENT SUCCESSFUL",
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      paymentChannelId,
      'Payment Notifications',
      channelDescription: 'Notifications for successful payments',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      styleInformation: bigTextStyle,
      groupKey: groupKey,
      setAsGroupSummary: false,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
    NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'PAYMENT SUCCESSFUL',
      'An amount of ₹$amount is credited into your Toll Seva account.',
      platformDetails,
    );

    await _showSummaryNotification();
  }

  Future<void> _showPaymentFailureNotification(String errorMessage) async {
    String formattedDate = "${DateTime.now().day}-${_getMonth(DateTime.now().month)}-${DateTime.now().year % 100}";
    String notificationMessage = "Your payment on $formattedDate has failed.\n\nReason: $errorMessage\n\nPlease try again.\n\nToll Seva";
    BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      notificationMessage,
      contentTitle: "PAYMENT FAILED",
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      paymentChannelId,
      'Payment Notifications',
      channelDescription: 'Notifications for all payment-related updates',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: bigTextStyle,
      groupKey: groupKey,
      setAsGroupSummary: false,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
    NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'PAYMENT FAILED',
      'Your payment on $formattedDate has failed.',
      platformDetails,
    );

    await _showSummaryNotification();
  }

  Future<void> _showSummaryNotification() async {
    AndroidNotificationDetails summaryNotificationDetails = AndroidNotificationDetails(
      paymentChannelId,
      'Payment Notifications',
      channelDescription: 'Summary of all payments',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: groupKey,
      setAsGroupSummary: true,
    );

    const DarwinNotificationDetails iOSSummaryDetails = DarwinNotificationDetails();
    NotificationDetails summaryDetails = NotificationDetails(android: summaryNotificationDetails, iOS: iOSSummaryDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Payment Updates',
      'You have multiple payment notifications',
      summaryDetails,
    );
  }

  String _getMonth(int month) {
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    return months[month - 1];
  }

  Future<void> _fetchInitialData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          var data = userDoc.data() as Map<String, dynamic>;
          _balance = (data['balance'] ?? 0.0).toDouble();
          _userName = data['firstName'] ?? 'User';
          _emailuser = data['email'] ?? 'Email';
          notifyListeners();
        }

        FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            var data = snapshot.data() as Map<String, dynamic>;
            _balance = (data['balance'] ?? 0.0).toDouble();
            _userName = data['firstName'] ?? 'User';
            _emailuser = data['email'] ?? 'Email';
            notifyListeners();
          }
        });
      } catch (e) {
        debugPrint("Error fetching initial data: $e");
      }
    }
  }

  Future<void> _fetchTransactions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .get();

        // Clear existing transactions first
        _transactions = [];

        for (var doc in snapshot.docs) {
          WalletTransaction transaction = WalletTransaction.fromFirestore(doc);
          _transactions.add(transaction);
        }

        // Set up listener for real-time updates
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .listen((snapshot) {
          // Create a new list to avoid reference issues
          List<WalletTransaction> updatedTransactions = [];

          for (var doc in snapshot.docs) {
            WalletTransaction transaction = WalletTransaction.fromFirestore(doc);
            updatedTransactions.add(transaction);
          }

          _transactions = updatedTransactions;
          notifyListeners();
        }, onError: (e) {
          debugPrint("Error in transaction listener: $e");
        });

        notifyListeners();
      } catch (e) {
        debugPrint("Error fetching transactions: $e");
      }
    }
  }

  // Public method to refresh transactions
  Future<void> refreshTransactions() async {
    await _fetchTransactions();
  }

  void _fetchUnreadNotificationCount() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        _unreadNotificationCount = snapshot.docs.length;
        _hasUnreadNotifications = _unreadNotificationCount > 0;
        notifyListeners();
      }, onError: (e) {
        debugPrint("Error fetching unread notification count: $e");
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    addMoney(_pendingAmount);
    _showPaymentSuccessNotification(_pendingAmount);
    _pendingAmount = 0;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    String errorMessage = response.message ?? "Unknown error occurred";
    _showPaymentFailureNotification(errorMessage);
    _storeFailedTransaction(errorMessage);
    _pendingAmount = 0;
    notifyListeners();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _pendingAmount = 0;
    notifyListeners();
  }

  double _pendingAmount = 0;

  double get balance => _balance;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  bool get hasUnreadNotifications => _hasUnreadNotifications;
  String get userName => _userName;
  int get unreadNotificationCount => _unreadNotificationCount;

  Future<void> _saveTransactionToFirestore(WalletTransaction transaction) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toFirestore(), SetOptions(merge: false));
      debugPrint("Transaction saved successfully to Firebase transactions!");
    } catch (e) {
      debugPrint("Error saving transaction to Firebase transactions: $e");
    }
  }

  Future<void> _saveTransactionForNotifications(WalletTransaction transaction) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
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
        'read': false,
      }, SetOptions(merge: false));
      debugPrint("Notification saved successfully to Firebase notifications!");
    } catch (e) {
      debugPrint("Error saving transaction to Firebase notifications: $e");
    }
  }

  Future<void> _storeFailedTransaction(String errorMessage) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String transactionId = generateTransactionId('Credit', DateTime.now());
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(transactionId)
        .set({
      'id': transactionId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'time': DateFormat('HH:mm:ss').format(DateTime.now()),
      'paymentType': 'Credit',
      'amount': _pendingAmount,
      'status': 'Failed',
      'method': 'Razorpay',
      'errorMessage': errorMessage,
      'read': false,
    });
    print('Failed transaction stored in Firestore');
  }

  Future<void> _updateBalanceInFirestore() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'balance': _balance});
        debugPrint("Balance updated in Firebase: $_balance");
      }
    } catch (e) {
      debugPrint("Error updating balance in Firebase: $e");
    }
  }

  String generateTransactionId(String paymentMethod, DateTime date) {
    String prefix = switch (paymentMethod) {
      'Paid' => 'DB',
      'Razorpay' => 'CR',
      'UPI' => 'UPI',
      _ => 'WD',
    };
    String timestamp = DateFormat('yyMMddHHmmss').format(date);
    String random = (1000 + date.microsecond % 9000).toString();
    return '$prefix$timestamp$random';
  }

  String _getRecipient(bool isDeduction) {
    return isDeduction ? "National Highways Authority of India (NHAI)" : "Toll Seva's wallet";
  }

  Future<bool> addMoneyWithRazorpay(double amount, int number) async {
    bool isAuthenticated = await _localAuthHelper.payment();
    if (!isAuthenticated) {
      debugPrint('Biometric authentication failed');
      return false;
    }

    _pendingAmount = amount;
    var options = {
      'key': 'rzp_test_BM4Uum7jvmrFBX',
      'amount': (amount * 100).toInt(),
      'name': 'Wallet Recharge',
      'description': 'Add money to wallet',
      'prefill': {'contact': number, 'email': _emailuser},
    };

    try {
      _razorpay.open(options);
      return true;
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      _pendingAmount = 0;
      notifyListeners();
      return false;
    }
  }

  void addMoney(double amount) {
    _balance += amount;
    String transactionId = generateTransactionId('Razorpay', DateTime.now());
    final transaction = WalletTransaction(
      id: transactionId,
      amount: amount,
      date: DateTime.now(),
      description: 'Credited to $_userName\'s wallet',
      paymentMethod: 'Razorpay',
      isDeduction: false,
      status: 'Completed',
      transactionId: transactionId,
    );

    _saveTransactionToFirestore(transaction);
    _saveTransactionForNotifications(transaction);
    _updateBalanceInFirestore();

    // Add to local transactions list immediately
    if (!_transactions.any((t) => t.id == transaction.id)) {
      _transactions.insert(0, transaction);
    }

    _hasUnreadNotifications = true;
    notifyListeners();

    if (onTransactionMade != null) {
      onTransactionMade!(transaction);
    }
  }

  void subtractMoney(double amount, BuildContext context) {
    if (_balance >= amount) {
      _balance -= amount;
      String transactionId = generateTransactionId('Paid', DateTime.now());
      final transaction = WalletTransaction(
        id: transactionId,
        amount: amount,
        date: DateTime.now(),
        description: 'Debited from $_userName\'s wallet by NHAI',
        paymentMethod: 'Paid',
        isDeduction: true,
        status: 'Completed',
        transactionId: transactionId,
      );

      _saveTransactionToFirestore(transaction);
      _saveTransactionForNotifications(transaction);
      _updateBalanceInFirestore();

      // Add to local transactions list immediately
      if (!_transactions.any((t) => t.id == transaction.id)) {
        _transactions.insert(0, transaction);
      }

      _hasUnreadNotifications = true;
      notifyListeners();

      if (onTransactionMade != null) {
        onTransactionMade!(transaction);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient Balance'), backgroundColor: Colors.red),
      );
    }
  }

  void addTransaction(WalletTransaction transaction) {
    if (!_transactions.any((t) => t.id == transaction.id)) {
      // Create a new list to avoid reference issues
      List<WalletTransaction> updatedTransactions = List.from(_transactions);
      updatedTransactions.insert(0, transaction);
      _transactions = updatedTransactions;
      notifyListeners();
    } else {
      debugPrint("Duplicate transaction detected, skipping: ${transaction.id}");
    }
  }

  void markNotificationsAsRead() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var notificationsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notifications');
        var snapshot = await notificationsRef.get();
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        debugPrint("All notifications marked as read in Firestore");
      } catch (e) {
        debugPrint("Error marking notifications as read in Firestore: $e");
      }
    }
    _hasUnreadNotifications = false;
    _unreadNotificationCount = 0;
    notifyListeners();
  }

  void setTransactionCallback(Function callback) {
    onTransactionMade = callback;
  }

  void updateBalance(double amount) {
    _balance = amount;
    _updateBalanceInFirestore();
    notifyListeners();
  }

  void onNotificationTap(WalletTransaction transaction) {}

  Future<void> addNotification(String title, String message, DateTime date, {required String transactionId}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(user.uid)
      //     .collection('notifications')
      //     .doc(transactionId)
      //     .set({
      //   'id': transactionId,
      //   'date': date.toIso8601String(),
      //   'paymentMethod': 'Notification',
      //   'description': message,
      //   'title': title,
      //   'read': false,
      // }, SetOptions(merge: false));

      _fetchUnreadNotificationCount();
      _hasUnreadNotifications = true;
      notifyListeners();

      BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        message,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      );

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        paymentChannelId,
        'Notification Updates',
        channelDescription: 'Notifications for wallet updates',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        styleInformation: bigTextStyle,
        groupKey: groupKey,
        setAsGroupSummary: false,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
      NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        platformDetails,
      );

      await _showSummaryNotification();
      debugPrint("Notification saved successfully to Firebase and shown locally!");
    } catch (e) {
      debugPrint("Error saving notification to Firebase: $e");
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}