/* import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

Future<pw.Font> _loadArabicFont() async {
  return pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
}

/// Generate a PDF for a single purchase order.
Future<pw.Document> generatePurchaseOrderPdf({
  required String orderId,
  required Map<String, dynamic> orderData,
  required Map<String, dynamic> supplierData,
  required Map<String, dynamic> companyData,
}) async {
  final pdf = pw.Document();
  final arabicFont = await _loadArabicFont();
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
              _buildItemsTable(orderData),
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

pw.Widget _buildItemsTable(Map<String, dynamic> data) {
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
 */ /* 

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PdfExporter {
  /// توليد ملف PDF لأمر الشراء
  ///
  /// [data]: بيانات أمر الشراء من Firestore
  /// [orderId]: رقم الطلب
  /// [vendorName]: اسم المورد
  /// [poNumber]: رقم أمر الشراء بالشكل المطلوب
  /// [isArabic]: لتحديد اتجاه النص RTL أو LTR
  /// [items]: قائمة الأصناف مع تفاصيلها
  /// [onQrGenerate]: دالة ترجع Widget QR
  static Future<Uint8List> generatePurchaseOrderPdf({
    required Map<String, dynamic> data,
    required String orderId,
    required String vendorName,
    required String poNumber,
    required bool isArabic,
    required List<dynamic> items,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    // required Widget Function() onQrGenerate,
  }) async {
    final pdf = pw.Document();

    final arabicFont = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) {
          return [
            pw.Text(
              isArabic ? 'أمر شراء' : 'Purchase Order',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${isArabic ? 'رقم الطلب' : 'Order ID'}: $orderId',
                  style: pw.TextStyle(fontSize: 12, font: arabicFont),
                ),
                pw.Text(
                  poNumber,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      font: arabicFont),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '${isArabic ? 'المورد' : 'Vendor'}: $vendorName',
              style: pw.TextStyle(fontSize: 14, font: arabicFont),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: isArabic
                  ? ['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي']
                  : ['Item', 'Quantity', 'Unit Price', 'Total'],
              data: items.map((item) {
                final name = item['name'] ?? '';
                final qty = item['quantity']?.toString() ?? '0';
                final unitPrice =
                    item['unitPrice']?.toStringAsFixed(2) ?? '0.00';
                final totalPrice =
                    (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
                return [
                  name,
                  qty,
                  unitPrice,
                  totalPrice.toStringAsFixed(2),
                ];
              }).toList(),
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, font: arabicFont),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: pw.TextStyle(font: arabicFont),
            ),
            pw.Divider(),
            pw.Align(
              alignment:
                  isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(
                '${isArabic ? 'الإجمالي' : 'Total'}: ${data['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Container(
                height: 100,
                width: 100,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: orderId,
                  drawText: false,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                isArabic ? 'امسح الكود لمزيد من التفاصيل' : 'Scan for details',
                style: pw.TextStyle(font: arabicFont, fontSize: 10),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
 */

/* 

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
//import 'package:pdf_fonts/pdf_fonts.dart';

class PdfExporter {
  static Future<Uint8List> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
  }) async {
    final pdf = pw.Document();
    final isArabic = orderData['isArabic'] ?? false;
    final poNumber = orderData['poNumber'] ?? orderId;
    final vendorName = supplierData['name'] ?? orderData['supplierName'] ?? 'Unknown Supplier';
    final items = orderData['items'] ?? [];
    final totalAmount = orderData['totalAmount']?.toStringAsFixed(2) ?? '0.00';

    final arabicFont = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => [
          _buildHeader(isArabic, arabicFont, poNumber),
          _buildVendorInfo(isArabic, arabicFont, vendorName),
          _buildItemsTable(isArabic, arabicFont, items),
          _buildTotalSection(isArabic, arabicFont, totalAmount),
          _buildQrCodeSection(orderId, isArabic, arabicFont),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(bool isArabic, pw.Font arabicFont, String poNumber) {
    return pw.Column(
      children: [
        pw.Text(
          isArabic ? 'أمر شراء' : 'Purchase Order',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          '${isArabic ? 'رقم الطلب' : 'Order ID'}: $poNumber',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: arabicFont),
        ),
      ],
    );
  }

  static pw.Widget _buildVendorInfo(bool isArabic, pw.Font arabicFont, String vendorName) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          '${isArabic ? 'المورد' : 'Vendor'}: $vendorName',
          style: pw.TextStyle(fontSize: 14, font: arabicFont),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildItemsTable(bool isArabic, pw.Font arabicFont, List<dynamic> items) {
    return pw.TableHelper.fromTextArray(
      headers: isArabic
          ? ['الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي']
          : ['Item', 'Quantity', 'Unit Price', 'Total'],
      data: items.map((item) {
        final name = item['name'] ?? '';
        final qty = item['quantity']?.toString() ?? '0';
        final unitPrice = item['unitPrice']?.toStringAsFixed(2) ?? '0.00';
        final totalPrice = (item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0);
        return [name, qty, unitPrice, totalPrice.toStringAsFixed(2)];
      }).toList(),
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: pw.TextStyle(font: arabicFont),
    );
  }

  static pw.Widget _buildTotalSection(bool isArabic, pw.Font arabicFont, String totalAmount) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Align(
          alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(
            '${isArabic ? 'الإجمالي' : 'Total'}: $totalAmount',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
            ),
          ),
        ),
        pw.SizedBox(height: 40),
      ],
    );
  }

  static pw.Widget _buildQrCodeSection(String orderId, bool isArabic, pw.Font arabicFont) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Container(
            height: 100,
            width: 100,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: orderId,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            isArabic ? 'امسح الكود لمزيد من التفاصيل' : 'Scan for details',
            style: pw.TextStyle(font: arabicFont, fontSize: 10),
          ),
        ],
      ),
    );
  }
} */
/* import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExporter {
  static Future<Uint8List> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();

    final items = (orderData['items'] as List?) ?? [];
    final total = (orderData['total'] ?? 0).toDouble();
    final isArabic = orderData['isArabic'] ?? false;

    final poNumber = orderData['poNumber'] ?? orderId;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isArabic ? 'أمر شراء' : 'Purchase Order',
                style: pw.TextStyle(fontSize: 24, font: font),
              ),
              pw.SizedBox(height: 10),
              pw.Text('PO #: $poNumber', style: pw.TextStyle(font: font)),
              pw.Text('Company: ${companyData['name_en'] ?? ''}',
                  style: pw.TextStyle(font: font)),
              pw.Text('Supplier: ${supplierData['name'] ?? ''}',
                  style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 10),
              pw.Text('Items:', style: pw.TextStyle(fontSize: 18, font: font)),
              pw.TableHelper.fromTextArray(
                cellStyle: pw.TextStyle(font: font),
                headers: ['Item', 'Qty', 'Price', 'Tax'],
                data: items.map<List<String>>((item) {
                  return [
                    item['name'] ?? '',
                    item['quantity'].toString(),
                    (item['price'] ?? 0).toString(),
                    (item['tax'] ?? 0).toString(),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total: ${total.toStringAsFixed(2)} EGP',
                  style: pw.TextStyle(fontSize: 16, font: font)),
              pw.SizedBox(height: 20),
              pw.Text('Scan QR for order info:',
                  style: pw.TextStyle(font: font)),
              pw.BarcodeWidget(
                data: poNumber,
                barcode: pw.Barcode.qrCode(),
                width: 100,
                height: 100,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
 */

/* Future<pw.Document> generatePurchaseOrderPdf({
  required String orderId,
  required Map<String, dynamic> orderData,
  required Map<String, dynamic> supplierData,
  required Map<String, dynamic> companyData,
}) async {
  // تحميل خط عربي
  // final arabicFont =
  //     pw.Font.ttf(await rootBundle.load("assets/fonts/Cairo-Black.ttf"));
  final arabicFont = await _loadArabicFont();
  final pdf = pw.Document();

  // إنشاء QR Code يحتوي على بيانات الفاتورة (بدون خادم)
  final qrData = _generateQrData(orderId, orderData, supplierData, companyData);
  final qrImage = await _generateQrImage(qrData);

  pdf.addPage(
    pw.Page(
      theme: pw.ThemeData.withFont(base: arabicFont),
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                // Header with Logo and QR
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyData['name_ar'],
                            style: const pw.TextStyle(fontSize: 18)),
                        pw.Text('${'invoice'.tr()} #$orderId',
                            style: const pw.TextStyle(fontSize: 16)),
                      ],
                    ),
                    pw.Container(
                      width: 100,
                      height: 100,
                      child: pw.Image(qrImage),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                    ),
                  ],
                ),

                pw.Divider(),

                // Supplier and Date Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        '${'date'.tr()}: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                    pw.Text('${'supplier'.tr()}: ${supplierData['name']}'),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Items Table with improved styling
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    font: arabicFont,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                  headers: [
                    'item'.tr(),
                    'quantity'.tr(),
                    'price'.tr(),
                    'total'.tr(),
                  ],
                  data: orderData['items']
                      .map((item) => [
                            item['name'],
                            item['quantity'].toString(),
                            '${item['unitPrice']} ${orderData['currency']}',
                            '${item['totalPrice']} ${orderData['currency']}',
                          ])
                      .toList(),
                ),

                pw.SizedBox(height: 20),

                // Totals Section
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          '${'subtotal'.tr()}: ${orderData['totalAmount']} ${orderData['currency']}'),
                      pw.Text(
                          '${'tax'.tr()}: ${orderData['taxAmount']} ${orderData['currency']}'),
                      pw.Text(
                          '${'total_amount'.tr()}: ${orderData['totalAmountAfterTax']} ${orderData['currency']}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Footer
                pw.Text('thanks_message'.tr(),
                    style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      },
    ),
  );

  return pdf;
} */
/* 
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;

Future<pw.Document> generatePurchaseOrderPdf({
  required String orderId,
  required Map<String, dynamic> orderData,
  required Map<String, dynamic> supplierData,
  required Map<String, dynamic> companyData,
  Uint8List? logoBytes,
  bool isArabic = true,
  String? qrData,
}) async {
  final arabicFont = await _loadArabicFont();
  final pdf = pw.Document();

  final qrData = _generateQrData(orderId, orderData, supplierData, companyData);
  final qrImage = await _generateQrImage(qrData);

  pdf.addPage(
    pw.Page(
      theme: pw.ThemeData.withFont(base: arabicFont),
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                // Header with Logo and QR
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyData['name_ar']),
                        pw.Text('${'invoice'.tr()} #$orderId'),
                      ],
                    ),
                    pw.Container(
                      width: 100,
                      height: 100,
                      child: pw.Image(qrImage),
                    ),
                  ],
                ),
                // Rest of your PDF content...
              ],
            ),
          ),
        );
      },
    ),
  );

  return pdf;
}

String _generateQrData(
  String orderId,
  Map<String, dynamic> orderData,
  Map<String, dynamic> supplierData,
  Map<String, dynamic> companyData,
) {
  // إنشاء نص يحتوي على بيانات الفاتورة الأساسية
  return '''
${'invoice'.tr()}: #$orderId
${'date'.tr()}: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
${'supplier'.tr()}: ${supplierData['name']}
${'company'.tr()}: ${companyData['name_ar']}
${'total_amount'.tr()}: ${orderData['totalAmountAfterTax']} ${orderData['currency']}
''';
}

/* Future<pw.MemoryImage> _generateQrImage(String data) async {
  try {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    final image = await qrPainter.toImage(200);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return pw.MemoryImage(bytes);
  } catch (e) {
    throw Exception('Failed to generate QR code: $e');
  }
}
 */

Future<pw.MemoryImage> _generateQrImage(String data) async {
  try {
    // Create QR code painter with proper parameters
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    // Convert to image using PictureRecorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 200.0;

    // Paint the QR code with proper size constraints
    qrPainter.paint(canvas, Size(size, size));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return pw.MemoryImage(bytes);
  } catch (e) {
    debugPrint('Error generating QR code: $e');
    // Fallback to text representation
    return _createFallbackQrImage(data);
  }
}

Future<pw.MemoryImage> _createFallbackQrImage(String text) async {
  final paragraphBuilder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontSize: 10,
    ),
  )
    ..pushStyle(ui.TextStyle(color: Colors.black))
    ..addText(text);

  final paragraph = paragraphBuilder.build();
  paragraph.layout(const ui.ParagraphConstraints(width: 200));

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawParagraph(paragraph, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  return pw.MemoryImage(bytes);
}

/* Future<pw.Font> _loadArabicFont() async {
  try {
    if (kIsWeb) {
      // للويب
      final response = await http.get(Uri.parse('fonts/Cairo-Black.ttf'));
      if (response.statusCode == 200) {
        return pw.Font.ttf(response.bodyBytes);
      } else {
        // جرب المسار البديل للويب
        final fallbackResponse = await http.get(Uri.parse('/fonts/Cairo-Black.ttf'));
        if (fallbackResponse.statusCode == 200) {
          return pw.Font.ttf(fallbackResponse.bodyBytes);
        }
        throw Exception('Failed to load font from web');
      }
    } else {
      // للجوال والكمبيوتر
      try {
        final fontData = await rootBundle.load('assets/fonts/Cairo-Black.ttf');
        return pw.Font.ttf(fontData);
      } catch (e) {
        // جرب المسار البديل
        final fontData = await rootBundle.load('fonts/Cairo-Black.ttf');
        return pw.Font.ttf(fontData);
      }
    }
  } catch (e) {
    debugPrint('Error loading Arabic font: $e');
    // استخدم خط افتراضي إذا فشل التحميل
    return pw.Font.courier();
  } }*/
/*  Future<pw.Font> _loadArabicFont() async {
  try {
    if (kIsWeb) {
      // للويب
      final response = await http.get(Uri.parse('fonts/Cairo-Black.ttf'));
      if (response.statusCode == 200) {
        final byteData = response.bodyBytes.buffer.asByteData(); // ✅ التحويل هنا
        return pw.Font.ttf(byteData);
      } else {
        final fallbackResponse = await http.get(Uri.parse('/fonts/Cairo-Black.ttf'));
        if (fallbackResponse.statusCode == 200) {
          final byteData = fallbackResponse.bodyBytes.buffer.asByteData(); // ✅ التحويل هنا
          return pw.Font.ttf(byteData);
        }
        throw Exception('Failed to load font from web');
      }
    } else {
      // للجوال والكمبيوتر
      try {
        final fontData = await rootBundle.load('assets/fonts/Cairo-Black.ttf');
        return pw.Font.ttf(fontData);
      } catch (e) {
        final fallbackFont = await rootBundle.load('fonts/Cairo-Black.ttf');
        return pw.Font.ttf(fallbackFont);
      }
    }
  } catch (e) {
    debugPrint('Error loading Arabic font: $e');
    return pw.Font.courier(); // fallback font
  }
}
 */
Future<pw.Font> _loadArabicFont() async {
  try {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    return pw.Font.ttf(fontData);
  } catch (e) {
    debugPrint('Error loading Arabic font: $e');
    return pw.Font.courier(); // Fallback to default font
  }
}
 */

/* class PdfExporter {

  static Future<pw.Document> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    Uint8List? logoBytes,
    bool isArabic = true,
    String? qrData,

  }) async {
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    final qrInfo =
        _generateQrData(orderId, orderData, supplierData, companyData);
    final qrImage = await _generateQrImage(qrInfo);

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                children: [
                  // Header with Logo and QR
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: isArabic
                            ? pw.CrossAxisAlignment.end
                            : pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isArabic
                                ? companyData['name_ar']
                                : companyData['name_en'],
                            style: pw.TextStyle(
                                fontSize: 18, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            '${'invoice'.tr()} #$orderId',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.Text(
                            '${'date'.tr()}: ${DateFormat('yyyy-MM-dd').format((orderData['orderDate'] as Timestamp).toDate())}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      pw.Container(
                        width: 100,
                        height: 100,
                        child: pw.Image(qrImage),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),

                  // Supplier Information
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${'supplier'.tr()}: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(supplierData['name'] ?? ''),
                    ],
                  ),

                  // Order Items Table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('item'.tr(),
                                textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('quantity'.tr(),
                                textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('price'.tr(),
                                textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('total'.tr(),
                                textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                      ..._buildOrderItemsRows(orderData['items']),
                    ],
                  ),

                  // Order Summary
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          '${'subtotal'.tr()}: ${orderData['totalAmount']} ${orderData['currency']}',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          '${'tax'.tr()}: ${orderData['totalTax']} ${orderData['currency']}',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          '${'total'.tr()}: ${orderData['totalAmountAfterTax']} ${orderData['currency']}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static List<pw.TableRow> _buildOrderItemsRows(List<dynamic> items) {
    return items.map<pw.TableRow>((item) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(item['name'] ?? ''),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(item['quantity']?.toString() ?? ''),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(item['unitPrice']?.toString() ?? ''),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(item['totalPrice']?.toString() ?? ''),
          ),
        ],
      );
    }).toList();
  }

  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
  ) {
    return '''
${'invoice'.tr()}: #$orderId
${'date'.tr()}: ${DateFormat('yyyy-MM-dd').format((orderData['orderDate'] as Timestamp).toDate())}
${'supplier'.tr()}: ${supplierData['name']}
${'company'.tr()}: ${companyData['name_ar']}
${'total_amount'.tr()}: ${orderData['totalAmountAfterTax']} ${orderData['currency']}
''';
  }

  static Future<pw.MemoryImage> _generateQrImage(String data) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = 200.0;

      qrPainter.paint(canvas, Size(size, size));

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error generating QR code: $e');
      return _createFallbackQrImage(data);
    }
  }

  static Future<pw.MemoryImage> _createFallbackQrImage(String text) async {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        fontSize: 10,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 200));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawParagraph(paragraph, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return pw.MemoryImage(bytes);
  }

  static Future<pw.Font> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Arabic font: $e');
      return pw.Font.courier();
    }
  }
}
 */
/* 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class PdfExporter {
  // Constants for styling
  static const double _headerFontSize = 18;
  static const double _bodyFontSize = 14;
  static const double _smallFontSize = 12;
  static const pw.EdgeInsets _defaultPadding = pw.EdgeInsets.all(8);

  // Cache for fonts
  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;

  static Future<pw.Document> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    String? base64Logo,
    bool isArabic = true,
  }) async {
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);
    final qrInfo =
        _generateQrData(orderId, orderData, supplierData, companyData);
    final qrImage = await _generateQrImage(qrInfo);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderId, orderData, companyData, qrImage,
                    logoBytes, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildSupplierSection(supplierData, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildOrderItemsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 20),
                _buildOrderSummary(orderData, isArabic, arabicFont),
                pw.Spacer(),
                _buildFooter(companyData, isArabic, arabicFont),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      return base64.decode(base64Logo.split(',').last);
    } catch (e) {
      debugPrint('Error decoding logo: $e');
      return null;
    }
  }

  static pw.Widget _buildHeader(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> companyData,
    pw.Widget qrImage,
    Uint8List? logoBytes,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 50),
            pw.Text(
              isArabic ? companyData['name_ar'] : companyData['name_en'],
              style: pw.TextStyle(
                fontSize: _headerFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'invoice'.tr()} #$orderId',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
              style: pw.TextStyle(
                fontSize: _smallFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ],
        ),
        pw.Container(
          width: 100,
          height: 100,
          child: qrImage,
        ),
      ],
    );
  }

  static String _formatOrderDate(dynamic orderDate) {
    if (orderDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(orderDate.toDate());
    }
    return orderDate?.toString() ?? '';
  }

/*   static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    return numValue.toStringAsFixed(2);
  } */

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';

    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;

    //return numValue.toStringAsFixed(2);
     final formatter = NumberFormat("#,##0.00", "en_US");
  String formatted = formatter.format(numValue);
  
  // استبدال الفواصل بنقاط إذا كانت العربية
  
    // formatted = formatted.replaceAll(',', 'X') // حرف مؤقت
    //                     .replaceAll('.', ',')
    //                     .replaceAll('X', '.');
  
  
  return formatted;
  }

  static pw.Widget _buildSupplierSection(
    Map<String, dynamic> supplierData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'supplier'.tr()}: ',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Expanded(
          child: pw.Text(
            supplierData['name'] ?? '',
            style: pw.TextStyle(
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign:  pw.TextAlign.center  //isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

/*   static pw.Widget _buildOrderItemsTable(
    Map<String, dynamic> orderData,
    pw.Font arabicFont,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeaderCell('item'.tr(), arabicFont),
            _buildTableHeaderCell('quantity'.tr(), arabicFont),
            _buildTableHeaderCell('price'.tr(), arabicFont),
            _buildTableHeaderCell('total'.tr(), arabicFont),
          ],
        ),
        ..._buildOrderItemsRows(orderData['items'] ?? [], arabicFont),
      ],
    );
  } */

/*   static pw.Widget _buildOrderItemsTable(
      Map<String, dynamic> orderData, pw.Font arabicFont,bool isArabic,) {
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableHeaderCell('item'.tr(), arabicFont),
              _buildTableHeaderCell('quantity'.tr(), arabicFont),
              _buildTableHeaderCell('price'.tr(), arabicFont),
              _buildTableHeaderCell('total'.tr(), arabicFont),
            ],
          ),
          ..._buildOrderItemsRows(orderData['items'] ?? [], arabicFont),
        ],
      ),
    );
  }
 */

  static pw.Widget _buildOrderItemsTable(
    Map<String, dynamic> orderData,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableHeaderCell('item'.tr(), arabicFont, isArabic),
              _buildTableHeaderCell('quantity'.tr(), arabicFont, isArabic),
              _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
              _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
            ],
          ),
          ..._buildOrderItemsRows(
              orderData['items'] ?? [], arabicFont, isArabic),
        ],
      ),
    );
  }

/*   static pw.Padding _buildTableHeaderCell(String text, pw.Font arabicFont) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: arabicFont,
        ),
      ),
    );
  } */
  static pw.Padding _buildTableHeaderCell(
    String text,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: arabicFont,
        ),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: _defaultPadding,
            child: pw.Text(
              item['name']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: pw.Text(
              item['quantity']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: pw.Text(
              _formatCurrency(item['unitPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: pw.Text(
              _formatCurrency(item['totalPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
        ],
      );
    }).toList();
  }

  /*  static pw.Widget _buildOrderSummary(
    Map<String, dynamic> orderData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Align(
      alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Column(
        crossAxisAlignment:
            isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${'subtotal'.tr()}: ${_formatCurrency(orderData['totalAmount'])} ${orderData['currency']}',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
          pw.Text(
            '${'tax'.tr()}: ${_formatCurrency(orderData['totalTax'])} ${orderData['currency']}',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
          pw.Text(
            '${'total'.tr()}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency']}',
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ],
      ),
    );
  }

 */

/* 
static pw.Widget _buildOrderSummary(
  Map<String, dynamic> orderData,
  bool isArabic,
  pw.Font arabicFont,
) {
  // دالة مساعدة لعرض العملة
  String formatCurrencyWithSymbol(num value, String currencyCode) {
    final formattedValue = _formatCurrency(value);
    if (currencyCode.toUpperCase() == 'EGP') {
      return isArabic ? 'ج.م $formattedValue' : 'L.E $formattedValue';
    }
    return '$formattedValue $currencyCode';
  }

  return pw.Align(
    alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'subtotal'.tr()}: ${formatCurrencyWithSymbol(orderData['totalAmount'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        ),
        pw.Text(
          '${'tax'.tr()}: ${formatCurrencyWithSymbol(orderData['totalTax'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        ),
        pw.Text(
          '${'total'.tr()}: ${formatCurrencyWithSymbol(orderData['totalAmountAfterTax'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        ),
      ],
    ),
  );
}
 */



// دالة لإنشاء خلية نصية
static pw.Widget _buildTableCell({
  required String text,
  required bool isArabic,
  required pw.Font arabicFont,
  pw.TextAlign align = pw.TextAlign.right,
  pw.FontWeight weight = pw.FontWeight.normal,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: _bodyFontSize,
        font: arabicFont,
        fontWeight: weight,
      ),
      textAlign: align,
    ),
  );
}

// دالة لتنسيق العملة
static String _formatCurrencyWithSymbol(dynamic value, String? currencyCode, bool isArabic) {
  final formattedValue = _formatCurrency(value);
  final code = currencyCode?.toUpperCase() ?? 'EGP';
  return code == 'EGP'
      ? (isArabic ? '$formattedValue ج.م' : '$formattedValue EGP')
      : '$formattedValue $code';
}


static pw.Widget _buildOrderSummary(
  Map<String, dynamic> orderData,
  bool isArabic,
  pw.Font arabicFont,
) {
  return pw.Container(
    alignment: isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft,
    child: pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.SizedBox(
        width: 250,
        child: pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
          },
          children: [
            // صف الإجمالي الفرعي
            _buildSummaryRow(
              label: 'subtotal'.tr(),
              value: orderData['totalAmount'],
              currency: orderData['currency'],
              isArabic: isArabic,
              arabicFont: arabicFont,
            ),
            
            // صف الضريبة
            _buildSummaryRow(
              label: 'tax'.tr(),
              value: orderData['totalTax'],
              currency: orderData['currency'],
              isArabic: isArabic,
              arabicFont: arabicFont,
            ),
            
            // صف الإجمالي النهائي
            _buildSummaryRow(
              label: 'total'.tr(),
              value: orderData['totalAmountAfterTax'],
              currency: orderData['currency'],
              isArabic: isArabic,
              arabicFont: arabicFont,
              isTotal: true,
            ),
          ],
        ),
      ),
    ),
  );
}

// دالة مساعدة لبناء صف كامل
static pw.TableRow _buildSummaryRow({
  required String label,
  required dynamic value,
  required String? currency,
  required bool isArabic,
  required pw.Font arabicFont,
  bool isTotal = false,
}) {
  return pw.TableRow(
    decoration: isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
    children: [
      // الخلية الأولى: التسمية
      _buildTableCell(
        text: isArabic ? _formatCurrencyWithSymbol(value, currency, isArabic) : ' ${label}:',
        isArabic: isArabic,
        arabicFont: arabicFont,
        align: isArabic ? pw.TextAlign.right : pw.TextAlign.right,
        weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      
      // الخلية الثانية: القيمة
      _buildTableCell(
        text: isArabic ? ' ${label}:' : _formatCurrencyWithSymbol(value, currency, isArabic),
        isArabic: isArabic,
        arabicFont: arabicFont,
        align: isArabic ? pw.TextAlign.right : pw.TextAlign.right,
        weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ],
  );
}

/* 
  static pw.Widget _buildOrderSummary(
    Map<String, dynamic> orderData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    // دالة مساعدة لتنسيق العملة
    String formatCurrencyWithSymbol(dynamic value, String? currencyCode) {
      final formattedValue = _formatCurrency(value);
      final code = currencyCode?.toUpperCase() ?? 'EGP';
      return code == 'EGP'
          ? (isArabic ? '$formattedValue ج.م' : '$formattedValue EGP')
          : ' $formattedValue $code ';
    }

    return pw.Container(
      alignment: isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: pw.Directionality(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: pw.SizedBox(
          width: 250, // تحديد عرض ثابت أو استخدام pw.FixedColumnWidth
          child: pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(width: 0.5, color: PdfColors.grey300),
              bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: isArabic
                        ? pw.Text(
                            formatCurrencyWithSymbol(orderData['totalAmount'],
                                orderData['currency']),
                            style: pw.TextStyle(
                              fontSize: _bodyFontSize,
                              font: arabicFont,
                            ),
                            textAlign: pw.TextAlign.right,
                          )
                        : pw.Text(
                            ' ${'subtotal'.tr()}:',
                            style: pw.TextStyle(
                              fontSize: _bodyFontSize,
                              font: arabicFont,
                            ),
                            textAlign: pw.TextAlign.right, //isArabic
                      //          ? pw.TextAlign.right
                    //            : pw.TextAlign.left,
                          ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: isArabic
                        ? pw.Text(
                            ' ${'subtotal'.tr()}:',
                            style: pw.TextStyle(
                              fontSize: _bodyFontSize,
                              font: arabicFont,
                            ),
                            textAlign: isArabic
                                ? pw.TextAlign.right
                                : pw.TextAlign.left,
                          )
                        : pw.Text(
                            formatCurrencyWithSymbol(orderData['totalAmount'],
                                orderData['currency']),
                            style: pw.TextStyle(
                              fontSize: _bodyFontSize,
                              font: arabicFont,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: isArabic? pw.Text(
                      formatCurrencyWithSymbol(
                          orderData['totalTax'], orderData['currency']),
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        font: arabicFont,
                      ),
                      textAlign: pw.TextAlign.right,
                    ) : pw.Text(
                      ' ${'tax'.tr()}:',
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        font: arabicFont,
                      ),
                      textAlign:pw.TextAlign.right,
                      //    isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child:isArabic ? pw.Text(
                      ' ${'tax'.tr()}:',
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        font: arabicFont,
                      ),
                      textAlign:
                          isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                    ) : pw.Text(
                      formatCurrencyWithSymbol(
                          orderData['totalTax'], orderData['currency']),
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        font: arabicFont,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: isArabic ?  pw.Text(
                      formatCurrencyWithSymbol(orderData['totalAmountAfterTax'],
                          orderData['currency']) ,
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textAlign: pw.TextAlign.right,
                    ) : pw.Text(
                      ' ${'total'.tr()}:',
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textAlign: pw.TextAlign.right
                       //   isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                    ) ,
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: isArabic ?  pw.Text(
                      ' ${'total'.tr()}:',
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textAlign:
                          isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                    ) : pw.Text(
                      formatCurrencyWithSymbol(orderData['totalAmountAfterTax'],
                          orderData['currency']) ,
                      style: pw.TextStyle(
                        fontSize: _bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                        font: arabicFont,
                      ),
                      textAlign: pw.TextAlign.right,
                    ) ,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
 */
/* static pw.Widget _buildOrderSummary(
  Map<String, dynamic> orderData,
  bool isArabic,
  pw.Font arabicFont,
) {
  // دالة مساعدة مع التحقق من القيم الفارغة
  String formatCurrencyWithSymbol(dynamic value, String? currencyCode) {
    if (value == null) return isArabic ? 'ج.م ٠٫٠٠' : 'L.E 0.00';
    
    final formattedValue = _formatCurrency(value);
    final code = currencyCode?.toUpperCase() ?? 'EGP';
    
    if (code == 'EGP') {
      return isArabic ? '$formattedValue ج.م' : '$formattedValue EGP';
    }
    return '$formattedValue $code';
  }

  return pw.Align(
    alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'subtotal'.tr()}: ${formatCurrencyWithSymbol(orderData['totalAmount'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
        ),
        pw.Text(
          '${'tax'.tr()}: ${formatCurrencyWithSymbol(orderData['totalTax'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
        ),
        pw.Text(
          '${'total'.tr()}: ${formatCurrencyWithSymbol(orderData['totalAmountAfterTax'], orderData['currency'])}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
        ),
      ],
    ),
  );
}

 */

  static pw.Widget _buildFooter(
    Map<String, dynamic> companyData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Column(
      crossAxisAlignment:
          isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text(
          companyData['address'] ?? '',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'phone'.tr()}: ${companyData['phone'] ?? ''}',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      ],
    );
  }

  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
  ) {
    return '''
${'invoice'.tr()}: #$orderId
${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}
${'supplier'.tr()}: ${supplierData['name']}
${'company'.tr()}: ${companyData['name_ar']}
${'total_amount'.tr()}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency']}
''';
  }

  static Future<pw.Widget> _generateQrImage(String data) async {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
      ),
      child: pw.Center(
        child: pw.Text(
          'QR Code\nPlaceholder',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  static Future<pw.Font> _getArabicFont() async {
    _cachedArabicFont ??= await _loadArabicFont();
    return _cachedArabicFont!;
  }

  static Future<pw.Font> _getLatinFont() async {
    _cachedLatinFont ??= await _loadLatinFont();
    return _cachedLatinFont!;
  }

  static Future<pw.Font> _loadArabicFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Tajawal-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Arabic font: $e');
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadLatinFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Roboto-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Latin font: $e');
      return pw.Font.helvetica();
    }
  }
}
 */ /* 

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class PdfExporter {
  // Constants for styling
  static const double _headerFontSize = 18;
  static const double _bodyFontSize = 14;
  static const double _smallFontSize = 12;
  static const pw.EdgeInsets _defaultPadding = pw.EdgeInsets.all(8);

  // Cache for fonts
  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;

  static Future<pw.Document> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    String? base64Logo,
    bool isArabic = true,
  }) async {
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);
    final qrInfo =
        _generateQrData(orderId, orderData, supplierData, companyData);
    final qrImage = await _generateQrImage(qrInfo);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderId, orderData, companyData, qrImage,
                    logoBytes, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildSupplierSection(supplierData, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildOrderItemsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 20),
                _buildOrderSummary(orderData, isArabic, arabicFont),
                pw.Spacer(),
                _buildFooter(companyData, isArabic, arabicFont),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      return base64.decode(base64Logo.split(',').last);
    } catch (e) {
      debugPrint('Error decoding logo: $e');
      return null;
    }
  }

  static pw.Widget _buildHeader(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> companyData,
    pw.Widget qrImage,
    Uint8List? logoBytes,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 50),
            pw.Text(
              isArabic ? companyData['name_ar'] : companyData['name_en'],
              style: pw.TextStyle(
                fontSize: _headerFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: pw.TextAlign.center, // isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'invoice'.tr()} #$orderId',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
              style: pw.TextStyle(
                fontSize: _smallFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ],
        ),
        pw.Container(
          width: 100,
          height: 100,
          child: qrImage,
        ),
      ],
    );
  }

  static String _formatOrderDate(dynamic orderDate) {
    if (orderDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(orderDate.toDate());
    }
    return orderDate?.toString() ?? '';
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    String formatted = formatter.format(numValue);
    return formatted;
  }

  static pw.Widget _buildSupplierSection(
    Map<String, dynamic> supplierData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'supplier'.tr()}: ',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: pw.TextAlign.center, // isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Expanded(
          child: pw.Text(
            supplierData['name'] ?? '',
            style: pw.TextStyle(
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOrderItemsTable(
    Map<String, dynamic> orderData,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: isArabic
              ? const pw.FlexColumnWidth(1)
              : const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: isArabic
              ? const pw.FlexColumnWidth(3)
              : const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: isArabic
                ? [
                    _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                     _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell(
                        'quantity'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('item'.tr(), arabicFont, isArabic)
                  ]
                : [
                    _buildTableHeaderCell('item'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell(
                        'quantity'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                  ],
          ),
          ..._buildOrderItemsRows(
              orderData['items'] ?? [], arabicFont, isArabic),
        ],
      ),
    );
  }

  static pw.Padding _buildTableHeaderCell(
    String text,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: arabicFont,
        ),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic ? pw.Text(
              _formatCurrency(item['totalPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            )  :  pw.Text(
              item['name']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic ? pw.Text(
              _formatCurrency(item['unitPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ) :  pw.Text(
              item['quantity']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic ? pw.Text(
              item['quantity']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ) : pw.Text(
              _formatCurrency(item['unitPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic ?  pw.Text(
              item['name']?.toString() ?? '',
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ) : pw.Text(
              _formatCurrency(item['totalPrice']),
              style: pw.TextStyle(
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
        ],
      );
    }).toList();
  }

  static pw.Widget _buildTableCell({
    required String text,
    required bool isArabic,
    required pw.Font arabicFont,
    pw.TextAlign align = pw.TextAlign.right,
    pw.FontWeight weight = pw.FontWeight.normal,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: _bodyFontSize,
          font: arabicFont,
          fontWeight: weight,
        ),
        textAlign: align,
      ),
    );
  }

  static String _formatCurrencyWithSymbol(
      dynamic value, String? currencyCode, bool isArabic) {
    final formattedValue = _formatCurrency(value);
    final code = currencyCode?.toUpperCase() ?? 'EGP';
    return code == 'EGP'
        ? (isArabic ? '$formattedValue ج.م' : '$formattedValue EGP')
        : '$formattedValue $code';
  }

  static pw.Widget _buildOrderSummary(
    Map<String, dynamic> orderData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Container(
      alignment: isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: pw.Directionality(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: pw.SizedBox(
          width: 250,
          child: pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(width: 0.5, color: PdfColors.grey300),
              bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              _buildSummaryRow(
                label: 'subtotal'.tr(),
                value: orderData['totalAmount'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              _buildSummaryRow(
                label: 'tax'.tr(),
                value: orderData['totalTax'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              _buildSummaryRow(
                label: 'total'.tr(),
                value: orderData['totalAmountAfterTax'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
                isTotal: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.TableRow _buildSummaryRow({
    required String label,
    required dynamic value,
    required String? currency,
    required bool isArabic,
    required pw.Font arabicFont,
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration:
          isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        _buildTableCell(
          text: isArabic
              ? _formatCurrencyWithSymbol(value, currency, isArabic)
              : ' $label:',
          isArabic: isArabic,
          arabicFont: arabicFont,
          align: isArabic ? pw.TextAlign.right : pw.TextAlign.right,
          weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        _buildTableCell(
          text: isArabic
              ? ' $label:'
              : _formatCurrencyWithSymbol(value, currency, isArabic),
          isArabic: isArabic,
          arabicFont: arabicFont,
          align: isArabic ? pw.TextAlign.right : pw.TextAlign.right,
          weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(
    Map<String, dynamic> companyData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Column(
      crossAxisAlignment:
          isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
              pw.Text(
          companyData['user_id'] ?? '',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          companyData['address'] ?? '',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'phone'.tr()}: ${companyData['phone'] ?? ''}',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      ],
    );
  }

  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
  ) {
    return '''
${'invoice'.tr()}: #$orderId
${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}
${'supplier'.tr()}: ${supplierData['name']}
${'company'.tr()}: ${companyData['name_ar']}
${'total_amount'.tr()}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency']}
''';
  }

  static Future<pw.Widget> _generateQrImage(String data) async {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
      ),
      child: pw.Center(
        child: pw.Text(
          'QR Code\nPlaceholder',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  static Future<pw.Font> _getArabicFont() async {
    _cachedArabicFont ??= await _loadArabicFont();
    return _cachedArabicFont!;
  }

  static Future<pw.Font> _getLatinFont() async {
    _cachedLatinFont ??= await _loadLatinFont();
    return _cachedLatinFont!;
  }

  static Future<pw.Font> _loadArabicFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Tajawal-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Arabic font: $e');
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadLatinFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Roboto-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Latin font: $e');
      return pw.Font.helvetica();
    }
  }
}
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PdfExporter {
  // Constants for styling
  static const double _headerFontSize = 18;
  static const double _bodyFontSize = 14;
  static const double _smallFontSize = 12;
  static const pw.EdgeInsets _defaultPadding = pw.EdgeInsets.all(8);

  // Cache for fonts
  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;

  static Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('displayName') ?? 'no_name'.tr();
  }

  static Future<pw.Document> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    String? base64Logo,
    bool isArabic = true,
  }) async {
    final userName = await _getUserName();
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);
    //  final qrInfo = _generateQrData(orderId, orderData, supplierData, companyData);
    //   final qrImage = await _generateQrImage(qrInfo);
    // إنشاء QR Code مع بيانات الطلب ورابط التنزيل
    final qrData =
        _generateQrData(orderId, orderData, supplierData, companyData, isArabic);
    final qrImage = await _generateRealQrImage(qrData, 200);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderId, orderData, companyData, qrImage,
                    logoBytes, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildSupplierSection(supplierData, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildOrderItemsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 20),
                _buildOrderSummary(orderData, isArabic, arabicFont),
                pw.Spacer(),
                _buildFooter(companyData, isArabic, arabicFont, userName),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  // إنشاء QR Code حقيقي بدلاً من النص البديل
  static Future<pw.Widget> _generateRealQrImage(
      String data, double size) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      final image = await qrPainter.toImageData(size);
      final qrImage = pw.MemoryImage(image!.buffer.asUint8List());

      return pw.Container(
        width: size,
        height: size,
        child: pw.Image(qrImage),
      );
    } catch (e) {
      debugPrint('Error generating QR: $e');
      return _generateQrPlaceholder();
    }
  }

  static pw.Widget _generateQrPlaceholder() {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
      ),
      child: pw.Center(
        child: pw.Text(
          'QR Code\nPlaceholder',
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  // تحسين بيانات QR لاحتواء معلومات أكثر
  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    bool isArabic,
  ) {
    final jsonData = {
      'type': 'purchase_order',
      'id': orderId,
      'date': _formatOrderDate(orderData['orderDate']),
      'supplier': {
        'id': supplierData['id'],
        'name': supplierData['name'],
      },
      'company': {
        'id': companyData['id'],
        'name': isArabic ? companyData['name_ar'] : companyData['name_en'],
      },
      'amount': orderData['totalAmountAfterTax'],
      'currency': orderData['currency'],
      'items': (orderData['items'] as List)
          .map((item) => {
                'name': item['name'],
                'quantity': item['quantity'],
                'price': item['unitPrice'],
              })
          .toList(),
    };

    return jsonEncode(jsonData);
  }

  // دالة لإنشاء رابط تنزيل PDF
  static Future<String> generatePdfDownloadUrl(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    String? base64Logo,
    bool isArabic,
  ) async {
    final pdf = await generatePurchaseOrderPdf(
      orderId: orderId,
      orderData: orderData,
      supplierData: supplierData,
      companyData: companyData,
      base64Logo: base64Logo,
      isArabic: isArabic,
    );

    final bytes = await pdf.save();
    final ref = FirebaseStorage.instance.ref('purchase_orders/$orderId.pdf');
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      return base64.decode(base64Logo.split(',').last);
    } catch (e) {
      debugPrint('Error decoding logo: $e');
      return null;
    }
  }

  static pw.Widget _buildHeader(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> companyData,
    pw.Widget qrImage,
    Uint8List? logoBytes,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes)),
            pw.Text(
              isArabic ? companyData['name_ar'] : companyData['name_en'],
              style: pw.TextStyle(
                fontSize: _headerFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              '${'invoice'.tr()} #$orderId',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
              style: pw.TextStyle(
                fontSize: _smallFontSize,
                font: arabicFont,
              ),
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ],
        ),
        pw.Container(
          width: 100,
          height: 100,
          child: qrImage,
        ),
      ],
    );
  }

  static String _formatOrderDate(dynamic orderDate) {
    if (orderDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(orderDate.toDate());
    }
    return orderDate?.toString() ?? '';
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  static pw.Widget _buildSupplierSection(
    Map<String, dynamic> supplierData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'supplier'.tr()}: ',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.Expanded(
          child: pw.Text(
            supplierData['name'] ?? '',
            style: pw.TextStyle(
              font: arabicFont,
            ),
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOrderItemsTable(
    Map<String, dynamic> orderData,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: isArabic
              ? const pw.FlexColumnWidth(1)
              : const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: isArabic
              ? const pw.FlexColumnWidth(3)
              : const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: isArabic
                ? [
                    _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell(
                        'quantity'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('item'.tr(), arabicFont, isArabic)
                  ]
                : [
                    _buildTableHeaderCell('item'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell(
                        'quantity'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                    _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                  ],
          ),
          ..._buildOrderItemsRows(
              orderData['items'] ?? [], arabicFont, isArabic),
        ],
      ),
    );
  }

  static pw.Padding _buildTableHeaderCell(
    String text,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: arabicFont,
        ),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic
                ? pw.Text(
                    _formatCurrency(item['totalPrice']),
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(
                    item['name']?.toString() ?? '',
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic
                ? pw.Text(
                    _formatCurrency(item['unitPrice']),
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(
                    item['quantity']?.toString() ?? '',
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic
                ? pw.Text(
                    item['quantity']?.toString() ?? '',
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(
                    _formatCurrency(item['unitPrice']),
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  ),
          ),
          pw.Padding(
            padding: _defaultPadding,
            child: isArabic
                ? pw.Text(
                    item['name']?.toString() ?? '',
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(
                    _formatCurrency(item['totalPrice']),
                    style: pw.TextStyle(font: arabicFont),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  ),
          ),
        ],
      );
    }).toList();
  }

  static String _formatCurrencyWithSymbol(
      dynamic value, String? currencyCode, bool isArabic) {
    final formattedValue = _formatCurrency(value);
    final code = currencyCode?.toUpperCase() ?? 'EGP';
    return code == 'EGP'
        ? (isArabic ? '$formattedValue ج.م' : '$formattedValue EGP')
        : '$formattedValue $code';
  }

  static pw.Widget _buildOrderSummary(
    Map<String, dynamic> orderData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Container(
      alignment: isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: pw.Directionality(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: pw.SizedBox(
          width: 250,
          child: pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(width: 0.5, color: PdfColors.grey300),
              bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              _buildSummaryRow(
                label: 'subtotal'.tr(),
                value: orderData['totalAmount'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              _buildSummaryRow(
                label: 'tax'.tr(),
                value: orderData['totalTax'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              _buildSummaryRow(
                label: 'total'.tr(),
                value: orderData['totalAmountAfterTax'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
                isTotal: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell({
    required String text,
    required bool isArabic,
    required pw.Font arabicFont,
    pw.TextAlign align = pw.TextAlign.right,
    pw.FontWeight weight = pw.FontWeight.normal,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: _bodyFontSize,
          font: arabicFont,
          fontWeight: weight,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.TableRow _buildSummaryRow({
    required String label,
    required dynamic value,
    required String? currency,
    required bool isArabic,
    required pw.Font arabicFont,
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration:
          isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        _buildTableCell(
          text: isArabic
              ? _formatCurrencyWithSymbol(value, currency, isArabic)
              : ' $label:',
          isArabic: isArabic,
          arabicFont: arabicFont,
          align: pw.TextAlign.right,
          weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        _buildTableCell(
          text: isArabic
              ? ' $label:'
              : _formatCurrencyWithSymbol(value, currency, isArabic),
          isArabic: isArabic,
          arabicFont: arabicFont,
          align: pw.TextAlign.right,
          weight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(
    Map<String, dynamic> companyData,
    bool isArabic,
    pw.Font arabicFont,
    String userName,
  ) {
    return pw.Column(
      crossAxisAlignment:
          isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text(
          userName, // Replaced user_id with company name
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          companyData['address'] ?? '',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'phone'.tr()}: ${companyData['phone'] ?? ''}',
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      ],
    );
  }

/*   static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
  ) {
    return '''
${'invoice'.tr()}: #$orderId
${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}
${'supplier'.tr()}: ${supplierData['name']}
${'company'.tr()}: ${companyData['name_ar']}
${'total_amount'.tr()}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency']}
''';
  } */

/*   static Future<pw.Widget> _generateQrImage(String data) async {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
      ),
      child: pw.Center(
        child: pw.Text(
          'QR Code\nPlaceholder',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
    );
  } */

  static Future<pw.Font> _getArabicFont() async {
    _cachedArabicFont ??= await _loadArabicFont();
    return _cachedArabicFont!;
  }

  static Future<pw.Font> _getLatinFont() async {
    _cachedLatinFont ??= await _loadLatinFont();
    return _cachedLatinFont!;
  }

  static Future<pw.Font> _loadArabicFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Tajawal-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Arabic font: $e');
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadLatinFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Roboto-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Latin font: $e');
      return pw.Font.helvetica();
    }
  }
}
