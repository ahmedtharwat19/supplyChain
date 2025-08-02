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
    required Map<String, dynamic> itemData,
    String? base64Logo,
    bool isArabic = true,
  }) async {
    final userName = await _getUserName();
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);
    //  final qrInfo = _generateQrData(orderId, orderData, supplierData, companyData);
    //   final qrImage = await _generateQrImage(qrInfo);
    // إنشاء QR Code مع بيانات الطلب ورابط التنزيل
    final qrData = _generateQrData(
        orderId, orderData, supplierData, companyData, itemData, isArabic);
    // طباعة البيانات للتأكد من أنها غير فارغة
    debugPrint('QR Data: $qrData');

    final qrImage = await _generateRealQrImage(qrData, 600);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont],
        ),
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 30,
          marginBottom: 30,
          marginLeft: 30,
          marginRight: 30,
        ),
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 20), // تعديل الهوامش// const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // _buildInvoiceTitle(isArabic, arabicFont),
                // pw.SizedBox(height: 20),
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
        gapless: false,
      );

      final image = await qrPainter.toImageData(size);

      if (image == null) {
        throw Exception('Failed to generate QR image');
      }
      final qrImage = pw.MemoryImage(image.buffer.asUint8List());

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
/*   static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemsData,
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
                'itemId': item['nameId'],
                'name': isArabic ? itemsData['name_ar'] : item['name_en'],
                'quantity': item['quantity'],
                'price': item['unitPrice'],
              })
          .toList(),
    };

    return jsonEncode(jsonData);
  }
 */

/*   static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemsData,
    bool isArabic,
  ) {
/*     final jsonData = {
      'invoice_info': {
        'number': orderId,
        'date': _formatOrderDate(orderData['orderDate']),
        'type': isArabic ? 'فاتورة شراء' : 'Purchase Order',
        'total': orderData['totalAmountAfterTax'],
        'currency': orderData['currency'],
      },
      'company': {
        'name': isArabic ? companyData['name_ar'] : companyData['name_en'],
        'tax_id': companyData['tax_id'] ?? '',
      },
      'supplier': {
        'name': supplierData['name'],
        'id': supplierData['id'],
      },
      'items': (orderData['items'] as List)
          .map((item) => {
                'name': isArabic ? itemsData['name_ar'] : item['name_en'],
                'quantity': item['quantity'],
                'price': item['unitPrice'],
              })
          .toList(),
    };

    return jsonEncode(jsonData); */

    final invoiceContent = '''
Invoice No: $orderId
Date: ${_formatOrderDate(orderData['orderDate'])}
Company: ${isArabic ? companyData['name_ar'] : companyData['name_en']}
Supplier: ${supplierData['name']}
Total: ${orderData['totalAmountAfterTax']} ${orderData['currency']}
''';

    return invoiceContent;
  }
 */

  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemData,
    bool isArabic,
  ) {
    // إنشاء محتوى نصي منظم للفاتورة
    /*  final invoiceContent = StringBuffer();
  
  invoiceContent.writeln('=== ${isArabic ? 'فاتورة شراء' : 'Purchase Order'} ===');
  invoiceContent.writeln('${isArabic ? 'رقم الفاتورة' : 'Invoice No'}: $orderId');
  invoiceContent.writeln('${isArabic ? 'التاريخ' : 'Date'}: ${_formatOrderDate(orderData['orderDate'])}');
  invoiceContent.writeln('${isArabic ? 'المورد' : 'Supplier'}: ${supplierData['name']}');
  invoiceContent.writeln('${isArabic ? 'الشركة' : 'Company'}: ${isArabic ? companyData['name_ar'] : companyData['name_en']}');
  invoiceContent.writeln('---------------------------------');
  
  // إضافة العناصر
  invoiceContent.writeln('${isArabic ? 'العناصر' : 'Items'}:');
  final items = orderData['items'] as List? ?? [];
  for (final item in items) {
    final itemName = isArabic ? item['name_ar'] : item['name_en'];
    invoiceContent.writeln(' - $itemName: ${item['quantity']} x ${_formatCurrency(item['unitPrice'])}');
  }
  
  invoiceContent.writeln('---------------------------------');
  invoiceContent.writeln('${isArabic ? 'المجموع قبل الضريبة' : 'Subtotal'}: ${_formatCurrency(orderData['totalAmount'])}');
  invoiceContent.writeln('${isArabic ? 'الضريبة' : 'Tax'}: ${_formatCurrency(orderData['totalTax'])}');
  invoiceContent.writeln('${isArabic ? 'المجموع النهائي' : 'Total'}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency']}');
  
  return invoiceContent.toString(); */
    /*   final jsonData = {
    'type': 'purchase_order',
    'id': orderId,
    'date': _formatOrderDate(orderData['orderDate']),
    'supplier': {
      'name': supplierData['name'],
      'id': supplierData['id'],
    },
    'company': {
      'name': isArabic ? companyData['name_ar'] : companyData['name_en'],
      'tax_id': companyData['tax_id'],
    },
      'items': (orderData['items'] as List)
          .map((item) => {
                'itemId': item['nameId'],
                'name': isArabic ? itemsData['name_ar'] : item['name_en'],
                'quantity': item['quantity'],
                'price': item['unitPrice'],
              })
          .toList(),
    'subtotal': orderData['totalAmount'],
    'tax': orderData['totalTax'],
    'total': orderData['totalAmountAfterTax'],
    'currency': orderData['currency'],
  };
  
  return jsonEncode(jsonData); */
    debugPrint('itemData structure: ${itemData.toString()}');
/*   final jsonData = {
    'type': 'purchase_order',
    'id': orderId,
    'date': _formatOrderDate(orderData['orderDate']),
    'supplier': {
      'name': supplierData['name'] ?? 'N/A',
      'id': supplierData['id'] ?? 'N/A',
    },
    'company': {
      'name': isArabic ? companyData['name_ar'] : companyData['name_en'],
      'tax_id': companyData['tax_id'] ?? 'N/A',
    },
    'items': (orderData['items'] as List).map((item) => {
      'itemId': item['itemId'] ?? 'N/A',
      'name': isArabic ? itemData['name_ar'] ?? 'N/A' : itemData['name_en'] ?? 'N/A',
      'quantity': item['quantity'],
      'price': item['unitPrice'],
    }).toList(),
    'subtotal': orderData['totalAmount'],
    'tax': orderData['totalTax'],
    'total': orderData['totalAmountAfterTax'],
    'currency': orderData['currency'] ?? 'EGP', // قيمة افتراضية
  };

  return jsonEncode(jsonData); */

    final items = (orderData['items'] as List).map((item) {
      final itemId = item['nameId'] ?? item['itemId'] ?? 'N/A';
      final itemDetails =
          itemData[itemId] ?? {}; // بيانات الصنف من جدول الأصناف
      final itemName =
          isArabic ? itemDetails['name_ar'] : itemDetails['name_en'];

      return {
        'name': itemName ?? 'غير معروف',
        'quantity': item['quantity'],
        'price': item['unitPrice'],
        'total': item['totalPrice'],
      };
    }).toList();

    final invoiceContent = '''
=== ${isArabic ? 'فاتورة شراء' : 'Purchase Order'} ===
${isArabic ? 'رقم الفاتورة' : 'Invoice No'}: $orderId
${isArabic ? 'التاريخ' : 'Date'}: ${_formatOrderDate(orderData['orderDate'])}
${isArabic ? 'المورد' : 'Supplier'}: ${supplierData['name']}
${isArabic ? 'الشركة' : 'Company'}: ${isArabic ? companyData['name_ar'] : companyData['name_en']}

${isArabic ? 'العناصر' : 'Items'}:
${items.map((item) => '• ${item['name']} - ${item['quantity']} x ${_formatCurrency(item['price'])} = ${_formatCurrency(item['total'])}').join('\n')}

${isArabic ? 'المجموع الفرعي' : 'Subtotal'}: ${_formatCurrency(orderData['totalAmount'])}
${isArabic ? 'الضريبة' : 'Tax'}: ${_formatCurrency(orderData['totalTax'])}
${isArabic ? 'المجموع النهائي' : 'Total'}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency'] ?? 'EGP'}
''';

    return invoiceContent;
  }

/*   static pw.Widget _buildInvoiceTitle(bool isArabic, pw.Font arabicFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          'purchase_order'.tr(),
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
 */
  // دالة لإنشاء رابط تنزيل PDF
  static Future<String> generatePdfDownloadUrl(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemData,
    String? base64Logo,
    bool isArabic,
  ) async {
    final pdf = await generatePurchaseOrderPdf(
      orderId: orderId,
      orderData: orderData,
      supplierData: supplierData,
      companyData: companyData,
      itemData: itemData,
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

/*   static pw.Widget _buildHeader(
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
              textAlign: isArabic
                  ? pw.TextAlign.right
                  : pw.TextAlign.left, //pw.TextAlign.center,
            ),
            pw.Text(
              '${'invoice'.tr()} #$orderId',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                font: arabicFont,
              ),
              // textDirection:
              //     isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
            pw.Text(
              '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
              style: pw.TextStyle(
                fontSize: _smallFontSize,
                font: arabicFont,
              ),
              // textDirection:
              //     isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
 */

/*   static pw.Widget _buildHeader(
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
      crossAxisAlignment: pw.CrossAxisAlignment.start, // إضافة هذا الخط
      children: [
        pw.Expanded(
          // تغليف العمود بـ Expanded
          child: pw.Column(
            crossAxisAlignment: isArabic
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.start, // إضافة هذا الخط
            children: [
              if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes)),
              pw.Text(
                isArabic ? companyData['name_ar'] : companyData['name_en'],
                style: pw.TextStyle(
                  fontSize: _headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                textDirection:
                    isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              ),
              pw.Text(
                '${'invoice'.tr()} #$orderId',
                style: pw.TextStyle(
                  fontSize: _bodyFontSize,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                textDirection:
                    isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              ),
              pw.Text(
                '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                style: pw.TextStyle(
                  fontSize: _smallFontSize,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                textDirection:
                    isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              ),
            ],
          ),
        ),
        pw.Container(
          width: 100,
          height: 100,
          child: qrImage,
        ),
      ],
    );
  }
 */

static pw.Widget _buildHeader(
  String orderId,
  Map<String, dynamic> orderData,
  Map<String, dynamic> companyData,
  pw.Widget qrImage,
  Uint8List? logoBytes,
  bool isArabic,
  pw.Font arabicFont,
) {
  return pw.Column(
    crossAxisAlignment:
        isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
    children: [
      // الصف العلوي: الشعار وبيانات الشركة
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoBytes != null)
            pw.Image(
              pw.MemoryImage(logoBytes),
              height: 200,
              width: 200,
            ),
          pw.Column(
            crossAxisAlignment: isArabic
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isArabic ? companyData['name_ar'] : companyData['name_en'],
                style: pw.TextStyle(
                  fontSize: _headerFontSize + 2,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              ),
              pw.Text(
                '${'invoice'.tr()} #$orderId',
                style: pw.TextStyle(
                  fontSize: _bodyFontSize,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              ),
              pw.Text(
                '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                style: pw.TextStyle(
                  fontSize: _smallFontSize,
                  font: arabicFont,
                ),
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            ],
          ),
        ],
      ),

      // صف جديد يحتوي على عنوان الفاتورة وQR Code
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // عنوان الفاتورة
          pw.Text(
            'purchase_order'.tr(),
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
            ),
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
          
          // QR Code
          pw.Container(
            width: 150,
            height: 150,
            child: qrImage,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
            ),
          ),
        ],
      ),

      // مسافة قبل باقي المحتوى
      pw.SizedBox(height: 20),
    ],
  );
}

/*   static pw.Widget _buildHeader(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> companyData,
    pw.Widget qrImage,
    Uint8List? logoBytes,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Column(
      crossAxisAlignment:
          isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        // الصف العلوي: الشعار وبيانات الشركة
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Image(
                pw.MemoryImage(logoBytes),
                height: 200,
                width: 200,
              ),
            pw.Column(
              crossAxisAlignment: isArabic
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isArabic ? companyData['name_ar'] : companyData['name_en'],
                  style: pw.TextStyle(
                    fontSize: _headerFontSize + 2,
                    fontWeight: pw.FontWeight.bold,
                    font: arabicFont,
                  ),
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                ),
                pw.Text(
                  '${'invoice'.tr()} #$orderId',
                  style: pw.TextStyle(
                    fontSize: _bodyFontSize,
                    font: arabicFont,
                  ),
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                ),
                pw.Text(
                  '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                  style: pw.TextStyle(
                    fontSize: _smallFontSize,
                    font: arabicFont,
                  ),
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              ],
            ),
          ],
        ),

        // مسافة بين الشعار وQR Code
        pw.SizedBox(height: 20),

        // QR Code في المركز
        pw.Container(
          width: 150,
          height: 150,
          child: qrImage,
        ),
      ],
    );
  }
 */
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
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
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

/*   static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      final itemName = isArabic ? item['name_ar'] : item['name_en'];
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
                  itemName ?? '',// (item[isArabic ? 'name_ar' : 'name_en']?.toString() ?? ''),
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
                    itemName ?? '', // item['name']?.toString() ?? '',
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
 */

  static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      final itemName =
          isArabic ? (item['name_ar'] ?? '') : (item['name_en'] ?? '');
      return pw.TableRow(
        children: isArabic
            ? [
                _buildItemCell(
                    _formatCurrency(item['totalPrice']), arabicFont, isArabic),
                _buildItemCell(
                    _formatCurrency(item['unitPrice']), arabicFont, isArabic),
                _buildItemCell(
                    item['quantity']?.toString() ?? '', arabicFont, isArabic),
                _buildItemCell(itemName, arabicFont, isArabic),
              ]
            : [
                _buildItemCell(itemName, arabicFont, isArabic),
                _buildItemCell(
                    item['quantity']?.toString() ?? '', arabicFont, isArabic),
                _buildItemCell(
                    _formatCurrency(item['unitPrice']), arabicFont, isArabic),
                _buildItemCell(
                    _formatCurrency(item['totalPrice']), arabicFont, isArabic),
              ],
      );
    }).toList();
  }

  static pw.Widget _buildItemCell(String text, pw.Font font, bool isArabic) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font),
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
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
          //  width: 250,
          child: pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(width: 0.5, color: PdfColors.grey300),
              bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
            ),
            columnWidths: {
              0: isArabic
                  ? const pw.FlexColumnWidth(3)
                  : const pw.FlexColumnWidth(1),
              1: isArabic
                  ? const pw.FlexColumnWidth(1)
                  : const pw.FlexColumnWidth(3),
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
              _buildAmountInWordsRow(
                value: orderData['totalAmountAfterTax'],
                currency: orderData['currency'],
                isArabic: isArabic,
                arabicFont: arabicFont,
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
      padding: const pw.EdgeInsets.all(8), //symmetric(vertical: 8),
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
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    numValue.toInt();
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
        // صف جديد للتفقيط
      ],
    );
  }

// دالة جديدة لإنشاء صف التفقيط
  static pw.TableRow _buildAmountInWordsRow({
    required dynamic value,
    required String? currency,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    try {
      final numValue =
          value is num ? value : double.tryParse(value.toString()) ?? 0;
      final intValue = numValue.toInt();

      // تحديد الحد الأقصى للرقم المدعوم
      const maxSupportedNumber = 999999999999; // حتى تريليون
      final safeValue = intValue.abs() > maxSupportedNumber
          ? (intValue.isNegative ? -maxSupportedNumber : maxSupportedNumber)
          : intValue;

      final amountInWords = isArabic
          ? _convertNumberToArabicWords(safeValue)
          : _convertNumberToEnglishWords(safeValue);

      final currencyText =
          currency = isArabic ? 'جنيهاً مصرياً' : 'Egyptian Pounds'; //= 'EGP'
      //? (isArabic ? 'جنيهاً مصرياً' : 'Egyptian Pounds')
      //: (isArabic ? 'دولاراً أمريكياً' : 'US Dollars');

      final fullText = isArabic
          ? '$amountInWords $currencyText فقط لا غير'
          : '$amountInWords $currencyText only';

      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey50),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: isArabic
                ? pw.Text(
                    fullText,
                    style: pw.TextStyle(
                      fontSize: _smallFontSize,
                      font: arabicFont,
                    ),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(isArabic ? 'المبلغ كتابة:' : 'Amount in words:',
                    style: pw.TextStyle(
                      fontSize: _smallFontSize,
                      font: arabicFont,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign
                        .right // isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                    ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: isArabic
                ? pw.Text(
                    isArabic ? 'المبلغ كتابة:' : 'Amount in words:',
                    style: pw.TextStyle(
                      fontSize: _smallFontSize,
                      font: arabicFont,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  )
                : pw.Text(
                    fullText,
                    style: pw.TextStyle(
                      fontSize: _smallFontSize,
                      font: arabicFont,
                    ),
                    textAlign:
                        isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error converting number to words: $e');
      return pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            isArabic
                ? 'تعذر تحويل المبلغ إلى كتابة'
                : 'Failed to convert amount to words',
            style: pw.TextStyle(
              fontSize: _smallFontSize,
              font: arabicFont,
              color: PdfColors.red,
            ),
          ),
        ),
        pw.Container(),
      ]);
    }
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

  static String _convertNumberToArabicWords(int number) {
    if (number == 0) return 'صفر';

    final List<String> units = [
      '',
      'واحد',
      'اثنان',
      'ثلاثة',
      'أربعة',
      'خمسة',
      'ستة',
      'سبعة',
      'ثمانية',
      'تسعة'
    ];
    final List<String> teens = [
      'عشرة',
      'أحد عشر',
      'اثنا عشر',
      'ثلاثة عشر',
      'أربعة عشر',
      'خمسة عشر',
      'ستة عشر',
      'سبعة عشر',
      'ثمانية عشر',
      'تسعة عشر'
    ];
    final List<String> tens = [
      '',
      'عشرة',
      'عشرون',
      'ثلاثون',
      'أربعون',
      'خمسون',
      'ستون',
      'سبعون',
      'ثمانون',
      'تسعون'
    ];
    final List<String> hundreds = [
      '',
      'مائة',
      'مئتان',
      'ثلاثمائة',
      'أربعمائة',
      'خمسمائة',
      'ستمائة',
      'سبعمائة',
      'ثمانمائة',
      'تسعمائة'
    ];
    final List<String> scales = ['', 'ألف', 'مليون', 'مليار', 'تريليون'];

    String convertLessThanOneThousand(int n, bool isLastScale) {
      if (n == 0) return '';
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        return n % 10 == 0
            ? tens[n ~/ 10]
            : '${units[n % 10]} و${tens[n ~/ 10]}';
      }
      return '${hundreds[n ~/ 100]}${n % 100 != 0 ? ' و${convertLessThanOneThousand(n % 100, false)}' : ''}';
    }

    if (number < 0) return 'سالب ${_convertNumberToArabicWords(-number)}';

    String result = '';
    int scaleIndex = 0;

    while (number > 0) {
      int chunk = number % 1000;
      if (chunk != 0) {
        String chunkStr = convertLessThanOneThousand(chunk, scaleIndex == 0);
        if (scaleIndex > 0) {
          chunkStr += ' ${scales[scaleIndex]}';
          if (chunk > 2 && scaleIndex > 0) chunkStr += 'ات';
        }
        result = '$chunkStr $result'.trim();
      }
      number ~/= 1000;
      scaleIndex++;
      if (scaleIndex >= scales.length) break; // تجنب تجاوز حدود القائمة
    }

    return result.trim();
  }

  static String _convertNumberToEnglishWords(int number) {
    if (number == 0) return 'zero';

    final List<String> units = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine'
    ];
    final List<String> teens = [
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen'
    ];
    final List<String> tens = [
      '',
      'ten',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety'
    ];
    final List<String> scales = [
      '',
      'thousand',
      'million',
      'billion',
      'trillion'
    ];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        return n % 10 == 0
            ? tens[n ~/ 10]
            : '${tens[n ~/ 10]}-${units[n % 10]}';
      }
      return '${units[n ~/ 100]} hundred${n % 100 != 0 ? ' and ${convertLessThanOneThousand(n % 100)}' : ''}';
    }

    if (number < 0) return 'negative ${_convertNumberToEnglishWords(-number)}';

    String result = '';
    int scaleIndex = 0;

    while (number > 0) {
      int chunk = number % 1000;
      if (chunk != 0) {
        String chunkStr = convertLessThanOneThousand(chunk);
        if (scaleIndex > 0) {
          chunkStr += ' ${scales[scaleIndex]}';
        }
        result = '$chunkStr $result'.trim();
      }
      number ~/= 1000;
      scaleIndex++;
      if (scaleIndex >= scales.length) break; // تجنب تجاوز حدود القائمة
    }

    return result.isEmpty ? 'zero' : result.trim();
  }
}
