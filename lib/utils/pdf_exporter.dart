import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

/// Generate a PDF for a single purchase order.
Future<pw.Document> generatePurchaseOrderPdf({
  required String orderId,
  required Map<String, dynamic> orderData,
  required Map<String, dynamic> supplierData,
  required Map<String, dynamic> companyData,
}) async {
  final pdf = pw.Document();

  final supplierName = supplierData['name'] ?? 'Unknown Supplier';
  final supplierCompany = supplierData['company'] ?? '';
  final paymentTerms = orderData['paymentTerms'] ?? 'غير محددة';

  final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();
  final formattedDate =
      createdAt != null ? DateFormat('yyyy/MM/dd').format(createdAt) : '---';

  final totalBeforeTax =
      orderData['totalBeforeTax']?.toStringAsFixed(2) ?? '0.00';
  final tax = orderData['tax']?.toStringAsFixed(2) ?? '0.00';
  final totalAmount = orderData['totalAmount']?.toStringAsFixed(2) ?? '0.00';

  final companyNameAr = companyData['name_ar'] ?? '';
  final companyNameEn = companyData['name_en'] ?? '';
  final companyAddress = companyData['address'] ?? '';
  final companyManager = companyData['manager_name'] ?? '';
  final companyPhone = companyData['manager_phone'] ?? '';

  final logoBase64 = companyData['logo_base64'] ?? '';
  Uint8List? logoBytes;
  if (logoBase64.isNotEmpty) {
    try {
      logoBytes = base64Decode(logoBase64);
    } catch (e) {
      debugPrint('Error decoding logo: $e');
      logoBytes = null;
    }
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          companyNameAr.isNotEmpty
                              ? companyNameAr
                              : companyNameEn,
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      if (companyAddress.isNotEmpty) pw.Text(companyAddress),
                      if (companyManager.isNotEmpty)
                        pw.Text('Manager: $companyManager'),
                      if (companyPhone.isNotEmpty)
                        pw.Text('Phone: $companyPhone'),
                    ],
                  ),
                  if (logoBytes != null)
                    pw.Container(
                      height: 80,
                      width: 160,
                      child: pw.Image(pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.contain),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Purchase Order',
                    style: pw.TextStyle(
                        fontSize: 28, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Order ID: #$orderId',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $formattedDate'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Supplier: $supplierName',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (supplierCompany.isNotEmpty) pw.Text(supplierCompany),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Order Items:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              _buildOrderItemsTable(orderData),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Before Tax: $totalBeforeTax ج.م'),
                      pw.Text('Tax: $tax ج.م'),
                      pw.Text('Total Amount: $totalAmount ج.م',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Payment Terms: $paymentTerms'),
              pw.Expanded(child: pw.Container()), // Push content to top
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated by PureSip Purchasing App',
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              )
            ],
          ),
        );
      },
    ),
  );

  return pdf;
}

pw.Widget _buildOrderItemsTable(Map<String, dynamic> data) {
  final List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(data['items'] ?? []);

  if (items.isEmpty) {
    return pw.Text('No item details available.');
  }

  return pw.TableHelper.fromTextArray(
    headers: ['Item Name', 'Type', 'Quantity', 'Unit Price', 'Total'],
    data: items.map((item) {
      final itemName = item['name'] ?? 'Unnamed';
      final itemType = _getItemTypeDisplayName(item['type'] ?? 'N/A');
      final quantity = item['quantity']?.toString() ?? '0';
      final unitPrice =
          (item['unitPrice'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final total = ((item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0))
          .toStringAsFixed(2);
      return [itemName, itemType, quantity, '$unitPrice ج.م', '$total ج.م'];
    }).toList(),
    border: pw.TableBorder.all(color: PdfColors.grey),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.all(8),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(2),
      4: const pw.FlexColumnWidth(2),
    },
  );
}

String _getItemTypeDisplayName(String type) {
  switch (type) {
    case 'raw_material':
      return 'خامة';
    case 'packaging_material':
      return 'مواد تعبئة وتغليف';
    default:
      return type;
  }
}
