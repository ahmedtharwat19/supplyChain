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
    final qrData =
        _generateQrData(orderId, orderData, supplierData, companyData,itemData, isArabic);
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
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left, //pw.TextAlign.center,
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
    final itemName = isArabic ? (item['name_ar'] ?? '') : (item['name_en'] ?? '');
    return pw.TableRow(
      children: isArabic
          ? [
              _buildItemCell(_formatCurrency(item['totalPrice']), arabicFont, isArabic),
              _buildItemCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic),
              _buildItemCell(item['quantity']?.toString() ?? '', arabicFont, isArabic),
              _buildItemCell(itemName, arabicFont, isArabic),
            ]
          : [
              _buildItemCell(itemName, arabicFont, isArabic),
              _buildItemCell(item['quantity']?.toString() ?? '', arabicFont, isArabic),
              _buildItemCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic),
              _buildItemCell(_formatCurrency(item['totalPrice']), arabicFont, isArabic),
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
