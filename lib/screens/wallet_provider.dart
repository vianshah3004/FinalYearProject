import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_auth_verify.dart';
import 'dart:io'; // For Platform checks

class WalletTransaction {
  final String id;
  final double amount;
  final int number;
  final DateTime date;
  final String description;
  final String paymentMethod;
  final bool isDeduction;
  final String? status; // Added as optional
  final String? transactionId;

  WalletTransaction({
    required this.id,
    required this.amount,
    this.number=1,
    required this.date,
    required this.description,
    required this.paymentMethod,
    this.isDeduction = false,
    this.status, // Optional parameter
    this.transactionId,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String dateString = "${data['Date']} ${data['Time']}";
    DateTime transactionDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateString);

    return WalletTransaction(
      id: data['transactionID'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: transactionDate,
      description: data['recipient'] ?? '',
      paymentMethod: data['paymentType'] == 'Credit' ? 'Razorpay' : 'Paid',
      isDeduction: data['paymentType'] == 'Debit',
      status: data['status'], // Optional, defaults to null if not present
      transactionId: data['transactionID'],
    );
  }
}

class WalletProvider with ChangeNotifier {
  double _balance = 0.0;
  final List<WalletTransaction> _transactions = [];
  bool _hasUnreadNotifications = false;
  String _userName='';
  String _emailuser='';
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

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();
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
    String formattedDate =
        "${DateTime.now().day}-${_getMonth(DateTime.now().month)}-${DateTime.now().year % 100}";

    String notificationMessage =
        "An amount of ₹$amount is credited into your Toll Seva account on $formattedDate.\n\n"
        "Your current balance is ₹$_balance.\n\n"
        "Toll Seva";

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

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'PAYMENT SUCCESSFUL',
      'An amount of ₹$amount is credited into your Toll Seva account.',
      platformDetails,
    );

    await _showSummaryNotification();
  }

  Future<void> _showPaymentFailureNotification(String errorMessage) async {
    String formattedDate =
        "${DateTime.now().day}-${_getMonth(DateTime.now().month)}-${DateTime.now().year % 100}";

    String notificationMessage =
        "Your payment on $formattedDate has failed.\n\n"
        "Reason: $errorMessage\n\n"
        "Please try again.\n\n"
        "Toll Seva";

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

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

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

    NotificationDetails summaryDetails = NotificationDetails(
      android: summaryNotificationDetails,
      iOS: iOSSummaryDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Payment Updates',
      'You have multiple payment notifications',
      summaryDetails,
    );
  }

  String _getMonth(int month) {
    const months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC"
    ];
    return months[month - 1];
  }

  Future<void> _fetchInitialData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        _balance = (data['balance'] ?? 0.0).toDouble();
        _userName = data['firstName'] ?? 'User';
        _emailuser = data['email'] ?? 'Email';

        notifyListeners();
      }

      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          var data = snapshot.data() as Map<String, dynamic>;
          _balance = (data['balance'] ?? 0.0).toDouble();
          _userName = data['firstName'] ?? 'User';
          _emailuser = data['email'] ?? 'Email';
          notifyListeners();
        }
      });
    }
  }

  Future<void> _fetchTransactions() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('Date', descending: true)
          .orderBy('Time', descending: true)
          .snapshots()
          .listen((snapshot) {
        _transactions.clear();
        for (var doc in snapshot.docs) {
          WalletTransaction transaction = WalletTransaction.fromFirestore(doc);
          _transactions.add(transaction);
        }
        notifyListeners();
      });
    }
  }

  Future<void> addNotification(String title, String body, DateTime date) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String transactionId = generateTransactionId('Notification', date);
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      String formattedTime = DateFormat('HH:mm:ss').format(date);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(transactionId)
          .set({
        'transactionID': transactionId,
        'Date': formattedDate,
        'Time': formattedTime,
        'title': title,
        'body': body,
        'read': false,
      });

      _hasUnreadNotifications = true;
      _unreadNotificationCount += 1;
      notifyListeners();

      // Show local notification
      BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
        body,
        contentTitle: title,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      );

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        paymentChannelId,
        'Payment Notifications',
        channelDescription: 'Notifications for payment updates',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: bigTextStyle,
        groupKey: groupKey,
        setAsGroupSummary: false,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      debugPrint("Error adding notification: $e");
    }
  }



  void _fetchUnreadNotificationCount() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false) // Only count unread notifications
          .snapshots()
          .listen((snapshot) {
        _unreadNotificationCount = snapshot.docs.length;
        _hasUnreadNotifications = _unreadNotificationCount > 0;
        notifyListeners();
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
      if (user == null) {
        debugPrint("No authenticated user found for saving transaction!");
        return;
      }
      debugPrint("Saving transaction for user: ${user.uid}");

      String transactionId = generateTransactionId(transaction.paymentMethod, transaction.date);
      String paymentType = transaction.isDeduction ? 'Debit' : 'Credit';
      String recipient = _getRecipient(transaction.isDeduction);

      String transactionDate = DateFormat('yyyy-MM-dd').format(transaction.date);
      String transactionTime = DateFormat('HH:mm:ss').format(transaction.date);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .set({
        'transactionID': transactionId,
        'Date': transactionDate,
        'Time': transactionTime,
        'paymentType': paymentType,
        'recipient': recipient,
        'amount': transaction.amount,
      });

      debugPrint("Transaction saved successfully to Firebase transactions!");
    } catch (e) {
      debugPrint("Error saving transaction to Firebase transactions: $e");
    }
  }

  Future<void> _saveTransactionForNotifications(WalletTransaction transaction) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No authenticated user found for saving notification!");
        return;
      }
      debugPrint("Saving notification for user: ${user.uid}");

      String transactionId = generateTransactionId(transaction.paymentMethod, transaction.date);
      String paymentType = transaction.isDeduction ? 'Debit' : 'Credit';
      String recipient = _getRecipient(transaction.isDeduction);

      String transactionDate = DateFormat('yyyy-MM-dd').format(transaction.date);
      String transactionTime = DateFormat('HH:mm:ss').format(transaction.date);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(transactionId)
          .set({
        'transactionID': transactionId,
        'Date': transactionDate,
        'Time': transactionTime,
        'paymentType': paymentType,
        'recipient': recipient,
        'amount': transaction.amount,
        'read': false, // Add read field, initially false
      });

      debugPrint("Transaction saved successfully to Firebase notifications!");
    } catch (e) {
      debugPrint("Error saving transaction to Firebase notifications: $e");
    }
  }

  Future<void> _storeFailedTransaction(String errorMessage) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'Date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'Time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'paymentType': 'Credit', // Adjust based on your context (e.g., 'Debit' or 'Credit')
        'amount': _pendingAmount, // Use the amount that was attempted
        'status': 'Failed',
        'method': 'Razorpay', // You can make this dynamic if needed
        'errorMessage': errorMessage,
        'read': false,
      });
      print('Failed transaction stored in Firestore');
    } catch (e) {
      print('Error storing failed transaction: $e');
    }
  }

  Future<void> _updateBalanceInFirestore() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'balance': _balance,
        });
        debugPrint("Balance updated in Firebase: $_balance");
      }
    } catch (e) {
      debugPrint("Error updating balance in Firebase: $e");
    }
  }

  String generateTransactionId(String paymentMethod, DateTime date) {
    String prefix = switch (paymentMethod) {
      'Debit' => 'DB',
      'Credit' => 'CR',
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

  Future<bool> addMoneyWithRazorpay(double amount,int number) async {
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
      'prefill': {
        'contact': number,
        'email': _emailuser,
      }
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
    final transaction = WalletTransaction(
      id: DateTime.now().toString(),
      amount: amount,
      date: DateTime.now(),
      description: 'Added to wallet',
      paymentMethod: 'Razorpay',
      isDeduction: false,
    );

    _saveTransactionToFirestore(transaction);
    _saveTransactionForNotifications(transaction);
    _updateBalanceInFirestore();
    addTransaction(transaction);
    _hasUnreadNotifications = true;
    notifyListeners();

    if (onTransactionMade != null) {
      onTransactionMade!(transaction);
    }
  }

  Future<void> subtractMoney(double amount, BuildContext context, {WalletTransaction? externalTransaction}) async {
    if (_balance >= amount) {
      _balance -= amount;
      WalletTransaction transactionToAdd;
      if (externalTransaction != null) {
        transactionToAdd = externalTransaction;
        // Ensure description is consistent with user name
        transactionToAdd = WalletTransaction(
          id: externalTransaction.id,
          amount: externalTransaction.amount,
          date: externalTransaction.date,
          paymentMethod: externalTransaction.paymentMethod,
          description: 'Debited from $_userName\'s wallet',
          isDeduction: externalTransaction.isDeduction,
          status: externalTransaction.status,
          transactionId: externalTransaction.transactionId,
        );
      } else {
        transactionToAdd = WalletTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          date: DateTime.now(),
          description: 'Debited from $_userName\'s wallet',
          paymentMethod: 'Paid',
          isDeduction: true,
          status: 'Completed',
          transactionId: 'deduct-${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      _saveTransactionToFirestore(transactionToAdd);
      _saveTransactionForNotifications(transactionToAdd);
      addTransaction(transactionToAdd);
      _updateBalanceInFirestore();
      _hasUnreadNotifications = true;
      notifyListeners();

      if (onTransactionMade != null) {
        onTransactionMade!(transactionToAdd);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Balance'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addTransaction(WalletTransaction transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  void markNotificationsAsRead() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var notificationsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications');
        var snapshot = await notificationsRef.get();

        // Update each notification to mark as read
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

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}