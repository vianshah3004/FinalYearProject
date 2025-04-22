import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_ui/screens/wallet_provider.dart';
import '../localized_text_widget.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';

class NotificationsPage1 extends StatefulWidget {
  final String previousPage;
  final int currentIndex;

  const NotificationsPage1({
    super.key,
    required this.previousPage,
    required this.currentIndex,
  });

  @override
  State<NotificationsPage1> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage1> {
  late int _currentIndex;
  bool _isClearing = false;
  String? firstName;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          firstName = data['firstName'] ?? 'User';
        });
      }
    } catch (e) {
      print("❌ Error fetching user data: $e");
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
    return '${prefix}${timestamp}${random}';
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return HomeScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
            (route) => false,
      );
    }
  }

  Color _getPaymentIconColor(String paymentType) {
    if (paymentType == 'Debit') {
      return Colors.deepOrange.shade300;
    }
    return Colors.lightGreen;
  }

  IconData _getPaymentIcon(String paymentType) {
    switch (paymentType) {
      case 'Debit':
        return Icons.confirmation_number;
      case 'Credit':
        return Icons.credit_score;
      default:
        return Icons.credit_score;
    }
  }

  String _formatDate(String dateStr, String timeStr) {
    final dateTimeStr = "$dateStr $timeStr";
    final dateTime = DateTime.parse(dateTimeStr);

    final dateString = "${dateTime.day} ${_monthName(dateTime.month)} ${dateTime.year}";
    final timeString = _formatTime(dateTime.hour, dateTime.minute);
    return "$dateString, $timeString";
  }

  String _monthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }

  String _formatTime(int hour, int minute) {
    final String suffix = hour >= 12 ? "pm" : "am";
    final int formattedHour = (hour > 12 || hour == 0) ? (hour % 12 == 0 ? 12 : hour % 12) : hour;
    final String formattedMinute = minute.toString().padLeft(2, '0');
    return "$formattedHour:$formattedMinute $suffix";
  }

  void _showNotificationDetailsDialog(BuildContext context, Map<String, dynamic> notification, double updatedBalance) {
    final isDebit = notification['paymentType'] == 'Debit';
    final transactionId = notification['transactionID'] ?? generateTransactionId(notification['paymentType'], DateTime.parse("${notification['Date']} ${notification['Time']}"));

    final Color headerBackgroundColor = isDebit ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final Color textColor = isDebit ? Colors.deepOrange : Colors.green[700]!;
    final Color buttonBackgroundColor = isDebit ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  decoration: BoxDecoration(
                    color: headerBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDebit ? Colors.deepOrange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getPaymentIcon(notification['paymentType']),
                          color: isDebit ? Colors.deepOrange : Colors.green,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedText(
                              text: isDebit ? 'Debited' : 'Credited',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LocalizedText(
                              text: isDebit ? 'From $firstName\'s wallet' : 'To $firstName\'s wallet',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        text: 'Transaction Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailItem(
                        title: 'Date',
                        value: notification['Date'],
                        icon: Icons.calendar_today_rounded,
                        iconColor: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        title: 'Time',
                        value: notification['Time'],
                        icon: Icons.access_time_rounded,
                        iconColor: const Color(0xFF1E88E5),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        title: 'Amount',
                        value: '₹${notification['amount']?.toStringAsFixed(2) ?? 'N/A'}',
                        icon: Icons.currency_rupee_rounded,
                        iconColor: Colors.amber.shade700,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        title: 'Transaction ID',
                        value: transactionId,
                        icon: Icons.receipt_long_rounded,
                        iconColor: const Color(0xFF5E35B1),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        title: 'Status',
                        value: notification['status'] ?? 'Completed',
                        icon: Icons.check_circle_rounded,
                        iconColor: Colors.green[600]!,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: buttonBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    alignment: Alignment.center,
                    child:LocalizedText(
                      text: 'Close',
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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

  Widget _buildDetailItem({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                text: title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                 value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF263238),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      print('Notification $notificationId deleted from Firestore');
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
              text:'Failed to delete notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('All notifications cleared from Firestore');
    } catch (e) {
      print('Error clearing notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
              text:'Failed to clear notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final walletProvider = Provider.of<WalletProvider>(context);
    final updatedBalance = walletProvider.balance;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF2C3E50),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Center(
          child:LocalizedText(
            text:
            'Notifications',
            style: GoogleFonts.poppins(
              color: const Color(0xFF2C3E50),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            padding: const EdgeInsets.only(right: 18),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.deepOrange,
              size: 28,
            ),
            onPressed: () {
              setState(() {
                _isClearing = true;
              });
              _clearAllNotifications().then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:LocalizedText(
                      text:
                      'All notifications cleared!',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: const Color(0xFF2C3E50),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
                setState(() {
                  _isClearing = false;
                });
                // Mark notifications as read in WalletProvider
                Provider.of<WalletProvider>(context, listen: false).markNotificationsAsRead();
              });
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: LocalizedText(
          text:'Please log in to view notifications'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('Date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/no_notify_1.jpg',
                    width: 300,
                    height: 300,
                  ),
                  const SizedBox(height: 16),
                  LocalizedText(
                    text:
                    'No notifications found!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child:LocalizedText(
                text:'Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data!.docs;

          return _isClearing
              ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: LocalizedText(
                    text:'Recent Activities',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index].data() as Map<String, dynamic>;
                      final notificationId = notifications[index].id;

                      return GestureDetector(
                        onTap: () => _showNotificationDetailsDialog(
                            context, notification, updatedBalance),
                        child: Dismissible(
                          key: Key(notificationId),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            _deleteNotification(notificationId);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Colors.redAccent, Colors.red],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: notification['paymentType'] == 'Debit'
                                          ? Colors.deepOrange.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      _getPaymentIcon(notification['paymentType']),
                                      color: _getPaymentIconColor(notification['paymentType']),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LocalizedText(
                                          text: notification['paymentType'] == 'Debit'
                                              ? 'Debited from $firstName\'s wallet'
                                              : 'Added to $firstName\'s wallet',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        LocalizedText(
                                          text:  _formatDate(notification['Date'], notification['Time']),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        LocalizedText(
                                          text: 'Amount: ₹${notification['amount']?.toStringAsFixed(2) ?? 'N/A'}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: notification['paymentType'] == 'Debit'
                                                ? Colors.deepOrange
                                                : Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}