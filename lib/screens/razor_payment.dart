import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_auth_verify.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final double amount;

  const RazorpayPaymentPage({super.key, required this.amount});

  @override
  _RazorpayPaymentPageState createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  late Razorpay _razorpay;
  double _currentBalance = 0.0;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final String groupKey = 'payment_group';
  final String paymentChannelId = 'payment_channel';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _fetchCurrentBalance();
    _initNotifications();
    _openCheckout(); // Automatically trigger payment
  }

  /// Request notification permissions (for Android 13+)
  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Initialize local notifications
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: androidInitSettings);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _requestNotificationPermission();
  }

  /// Fetch user's current wallet balance
  Future<void> _fetchCurrentBalance() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _currentBalance = (userDoc['balance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print("Error fetching wallet balance: $e");
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
  }

  /// Open Razorpay payment
  void _openCheckout() async {
    double enteredAmount = widget.amount;
    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid amount")),
      );
      Navigator.pop(context);
      return;
    }

    LocalAuthHelper authHelper = LocalAuthHelper();
    bool isAuthenticated = await authHelper.payment();

    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Authentication Failed! Payment canceled.")),
      );
      Navigator.pop(context);
      return;
    }

    print("✅ Authentication successful! Proceeding to Razorpay...");

    var options = {
      'key': 'rzp_test_BM4Uum7jvmrFBX', // Replace with your Razorpay key
      'amount': (enteredAmount * 100).toInt(),
      'name': 'Toll Seva',
      'description': 'Wallet Top-Up',
      'prefill': {
        'contact': '9876543210',
        'email': 'user@example.com',
      },
      'theme': {'color': '#3399cc'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print("Error: $e");
      Navigator.pop(context);
    }
  }

  /// Handle successful Razorpay payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    double enteredAmount = widget.amount;

    if (enteredAmount > 0) {
      await _updateWalletBalance(enteredAmount);
      await _storeTransaction(enteredAmount, response.paymentId!);

      await _fetchCurrentBalance();
      _showPaymentSuccessNotification(enteredAmount, _currentBalance);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Successful: ₹$enteredAmount")),
    );
    Navigator.pop(context); // Return to WalletTab after success
  }

  /// Store transaction details in Firestore
  Future<void> _storeTransaction(double amount, String transactionId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String userId = user.uid;
      DocumentReference userDoc =
      FirebaseFirestore.instance.collection('users').doc(userId);

      CollectionReference transactions = userDoc.collection('transactions');

      await transactions.doc(transactionId).set({
        'transactionId': transactionId,
        'amount': amount,
        'method': 'Razorpay',
        'dateTime': Timestamp.now(),
        'to': 'Wallet',
      });

      print("Transaction stored successfully");
    } catch (e) {
      print("Error storing transaction: $e");
    }
  }

  /// Update wallet balance
  Future<void> _updateWalletBalance(double amount) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      DocumentReference userDoc =
      FirebaseFirestore.instance.collection('users').doc(userId);

      await userDoc.update({'balance': _currentBalance + amount});

      setState(() {
        _currentBalance += amount;
      });
    } catch (e) {
      print("Error updating balance: $e");
    }
  }

  /// Handle payment failure with grouped notifications
  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    String errorMessage = response.message ?? "Unknown error occurred";

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
      'payment_channel',
      'Payment Notifications',
      channelDescription: 'Notifications for all payment-related updates',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: bigTextStyle,
      groupKey: 'payment_group',
      setAsGroupSummary: false,
    );

    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'PAYMENT FAILED',
      'Your payment on $formattedDate has failed.',
      platformDetails,
    );

    _showSummaryNotification();
    Navigator.pop(context); // Return to WalletTab after failure
  }

  /// Show notification for successful payment with grouping
  Future<void> _showPaymentSuccessNotification(double amount, double currentBalance) async {
    String formattedDate =
        "${DateTime.now().day}-${_getMonth(DateTime.now().month)}-${DateTime.now().year % 100}";

    String notificationMessage =
        "An amount of ₹$amount is credited into your Toll Seva account on $formattedDate.\n\n"
        "Your current balance is ₹$currentBalance.\n\n"
        "Toll Seva";

    BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      notificationMessage,
      contentTitle: "PAYMENT SUCCESSFUL",
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'payment_channel',
      'Payment Notifications',
      channelDescription: 'Notifications for successful payments',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      styleInformation: bigTextStyle,
      groupKey: 'payment_group',
      setAsGroupSummary: false,
    );

    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'PAYMENT SUCCESSFUL',
      'An amount of ₹$amount is credited into your Toll Seva account.',
      platformDetails,
    );

    _showSummaryNotification();
  }

  /// Show a summary notification to group multiple notifications
  Future<void> _showSummaryNotification() async {
    AndroidNotificationDetails summaryNotificationDetails = AndroidNotificationDetails(
      'payment_channel',
      'Payment Notifications',
      channelDescription: 'Summary of all payments',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'payment_group',
      setAsGroupSummary: true,
    );

    NotificationDetails summaryDetails = NotificationDetails(android: summaryNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Payment Updates',
      'You have multiple payment notifications',
      summaryDetails,
    );
  }

  /// Helper function to get month name in uppercase
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

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading while Razorpay opens
      ),
    );
  }
}