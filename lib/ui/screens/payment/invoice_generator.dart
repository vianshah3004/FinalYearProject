// invoice_generator.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceGenerator {
  static Future<void> generateAndDownloadInvoice({
    required String transactionId,
    required DateTime date,
    required String paymentMethod,
    required double amount,
    required bool isDeduction,
    required String tollPlaza,
    required String vehicleNumber,
  }) async {
    final pdf = pw.Document();

    final invoiceTitle = "Transaction Invoice";
    final authorityName = "National Highways Authority of India (NHAI)";
    final gstNumber = "27AACTN1234F1ZP";
    String vehicleNumber = 'Not Set';
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        DocumentSnapshot userData = await userDocRef.get();
        if (userData.exists) {
          vehicleNumber = userData['vehicle']?['numberPlate'] ?? 'Not Set';

        }
      }
    } catch (e) {
      print("Error fetching vehicle number: $e");
    }



    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  "Government of India",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  authorityName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Invoice No: $transactionId",
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                "Date: ${date.day}-${date.month}-${date.year}",
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                "Time: ${date.hour}:${date.minute}",
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Transaction Details",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text("Amount Paid: INR ${amount.toStringAsFixed(2)}"),
              pw.Text("Payment Method: $paymentMethod"),
              pw.Text("Transaction Type: ${isDeduction ? "Deduction (Toll Payment)" : "Credit"}"),
              pw.Text("Status: Successful"),
              pw.Text("Toll Plaza: $tollPlaza"),
              pw.Text("Vehicle Number: $vehicleNumber"),
              pw.Text("GST No: $gstNumber"),
              pw.SizedBox(height: 10),
              pw.Text(
                "Tax Details",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text("Base Toll Fee: INR ${(amount - 10).toStringAsFixed(2)}"),
              pw.Text("GST (18%): INR 10.00"),
              pw.Text("Total Amount Paid: INR ${amount.toStringAsFixed(2)}"),
              pw.SizedBox(height: 10),
              pw.NewPage(),
              pw.Text(
                "Disclaimer",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text(
                "This invoice is electronically generated and does not require a physical signature. "
                    "The amount charged is in accordance with the Government of India Toll Policy. "
                    "For any queries, please contact NHAI Toll Support at 1800-123-4567 or visit www.nhai.gov.in.",
              ),
            ],
          ),
        ],
      ),
    );

    // Request storage permission
    await Permission.storage.request();

    // Get storage directory
    final directory = await getExternalStorageDirectory();
    final filePath = "${directory!.path}/Toll_Invoice_$transactionId.pdf";

    // Save PDF file
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Open the file after saving
    OpenFilex.open(filePath);
  }
}