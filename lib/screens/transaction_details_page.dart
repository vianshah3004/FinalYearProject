// transaction_details_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localized_text_widget.dart';
import 'wallet_provider.dart' as wallet;
import 'invoice_generator.dart';

class TransactionDetailsPage extends StatelessWidget {
  final wallet.WalletTransaction transaction;

  const TransactionDetailsPage({super.key, required this.transaction});

  Future<void> _downloadInvoice(BuildContext context) async {
    try {
      String transactionId = generateTransactionId(transaction.paymentMethod, transaction.date);
      String tollPlaza = _getRecipient(transaction.isDeduction);
      // Use a default vehicle number if not available in the transaction object
      String vehicleNumber = "MH-12-AB-1234";

      await InvoiceGenerator.generateAndDownloadInvoice(
        transactionId: transactionId,
        date: transaction.date,
        paymentMethod: transaction.paymentMethod,
        amount: transaction.amount,
        isDeduction: transaction.isDeduction,
        tollPlaza: tollPlaza,
        vehicleNumber: vehicleNumber,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            text:'Invoice downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error downloading invoice: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
              text:'Failed to download invoice'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = transaction.date;
    final dateString = "${date.day} ${_monthName(date.month)} ${date.year}";
    final timeString = "${_formatTime(date.hour, date.minute)}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C3E50)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title:LocalizedText(
          text: 'Transaction Details',
          style: GoogleFonts.poppins(
            color: const Color(0xFF2C3E50),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 0),
              // _buildStatusIcon(),
              const SizedBox(height: 15),
              _buildAmountCard(),
              const SizedBox(height: 24),
              _buildTransactionInfo(dateString, timeString),
              const SizedBox(height: 24),
              _buildPaymentMethodCard(),
              const SizedBox(height: 24),
              _buildRecipientCard(),
              const SizedBox(height: 24),
              _buildDownloadInvoiceButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Material(
      elevation: 18.0,
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        width: double.infinity,
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
            stops: const [0.4, 0.6, 0.85],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LocalizedText(
                  text: transaction.isDeduction ? 'Amount Paid' : 'Amount Added',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '₹ ${transaction.amount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: transaction.isDeduction
                    ? Colors.deepOrange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    transaction.isDeduction ? Icons.payment : Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  LocalizedText(
                    text: 'Completed',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionInfo(String dateString, String timeString) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child:LocalizedText(
              text: 'Transaction Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today, 'Date', dateString, Colors.red.shade400),
          _buildInfoRow(Icons.access_time, 'Time', timeString, Colors.lightBlueAccent.shade400),
          _buildInfoRow(
            Icons.receipt_long_rounded,
            'Transaction ID',
            generateTransactionId(transaction.paymentMethod, transaction.date),
            const Color(0xFF5E35B1),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    // Determine the display payment method based on transaction type
    String displayPaymentMethod = transaction.description == 'Added to wallet'
        ? 'Credit'
        : (transaction.paymentMethod == 'Paid' ? 'Debit' : transaction.paymentMethod);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: transaction.isDeduction
                  ? Colors.deepOrange.shade300.withOpacity(0.1)
                  : Colors.lightGreen.shade500.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payment,
              color: transaction.isDeduction ? Colors.deepOrange.shade300 : Colors.lightGreen.shade500,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                text:'Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              LocalizedText(
                text:  displayPaymentMethod,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade400.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance,
              color: Colors.amber.shade400,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  text: transaction.isDeduction ? 'Paid To' : 'Received By',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                LocalizedText(
                  text: _getRecipient(transaction.isDeduction),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadInvoiceButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _downloadInvoice(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download, size: 24),
            const SizedBox(width: 8),
            LocalizedText(
              text: 'Download Invoice',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                text: label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
}