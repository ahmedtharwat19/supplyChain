// lib/utils/stock_pdf_exporter.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:puresip_purchasing/pages/stock_movements/services/movement_utils.dart';

class StockPdfExporter {
  // Constants for styling
  static const double _headerFontSize = 18;
  static const double _bodyFontSize = 14;
  static const double _smallFontSize = 12;
  static const pw.EdgeInsets _defaultPadding = pw.EdgeInsets.all(8);

  // Cache for fonts
  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;

  static Future<pw.Document> generateStockMovementsPdf({
    required List<QueryDocumentSnapshot> docs,
    required Map<String, String> productNames,
    required Map<String, int> productStocks,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> factoryData,
    required DateTime startDate,
    required DateTime endDate,
    bool isArabic = true,
  }) async {
    final pdf = pw.Document();
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(companyData, factoryData, startDate, endDate, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildMovementsTable(docs, productNames, productStocks, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildFooter(isArabic, arabicFont),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(
    Map<String, dynamic> companyData,
    Map<String, dynamic> factoryData,
    DateTime startDate,
    DateTime endDate,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'stock_movements_report'.tr(),
          style: pw.TextStyle(
            fontSize: _headerFontSize + 2,
            fontWeight: pw.FontWeight.bold,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '${'company'.tr()}: ${isArabic ? companyData['nameAr'] : companyData['nameEn']}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'factory'.tr()}: ${isArabic ? factoryData['nameAr'] : factoryData['nameEn']}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'date_range'.tr()}: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
        pw.Text(
          '${'generated_on'.tr()}: ${_formatDate(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: _bodyFontSize,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      ],
    );
  }

  static pw.Widget _buildMovementsTable(
    List<QueryDocumentSnapshot> docs,
    Map<String, String> productNames,
    Map<String, int> productStocks,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    // تجميع البيانات حسب المنتج
    final Map<String, List<Map<String, dynamic>>> productMovements = {};
   
    for (var doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final productId = data['productId']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'unknown';
        final quantity = (data['quantity'] ?? 0) as int;
        final timestamp = data['date'] as Timestamp?;
        final date = timestamp != null ? timestamp.toDate() : DateTime.now();

        final movementInfo = MovementUtils.getMovementTypeInfo(type, quantity);
        
        if (!productMovements.containsKey(productId)) {
          productMovements[productId] = [];
        }
        
        productMovements[productId]!.add({
          'date': date,
          'type_text': movementInfo['type_text'],
          'in': movementInfo['in'],
          'out': movementInfo['out'],
        });
      } catch (e) {
        debugPrint('[ERROR] Processing movement: $e');
      }
    }

    return pw.Column(
      children: [
        for (final productId in productMovements.keys)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // عنوان المنتج
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '${'product'.tr()}: ${productNames[productId] ?? 'Unknown'}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    font: arabicFont,
                  ),
                ),
              ),
              
              // جدول الحركات لهذا المنتج
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // رأس الجدول
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeaderCell('#', arabicFont, isArabic),
                      _buildTableHeaderCell('date'.tr(), arabicFont, isArabic),
                      _buildTableHeaderCell('movement_type'.tr(), arabicFont, isArabic),
                      _buildTableHeaderCell('IN', arabicFont, isArabic),
                      _buildTableHeaderCell('OUT', arabicFont, isArabic),
                      _buildTableHeaderCell('balance'.tr(), arabicFont, isArabic),
                    ],
                  ),
                  // بيانات الجدول
                  ..._buildProductTableRows(productMovements[productId]!, arabicFont, isArabic),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ),
      ],
    );
  }

  static List<pw.TableRow> _buildProductTableRows(
    List<Map<String, dynamic>> movements,
    pw.Font font,
    bool isArabic,
  ) {
    final List<pw.TableRow> rows = [];
    
    // حساب الرصيد التدريجي
    int runningBalance = 0;
    final movementsWithBalance = movements.map((movement) {
      runningBalance = (runningBalance - movement['out'] + movement['in']).toInt();
      return {
        ...movement,
        'balance': runningBalance,
      };
    }).toList();

    int index = 1;
    for (final movement in movementsWithBalance) {
      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(index.toString(), font, isArabic),
            _buildTableCell(_formatDate(movement['date']), font, isArabic),
            _buildTableCell(movement['type_text'], font, isArabic),
            _buildTableCell(movement['in'].toString(), font, isArabic),
            _buildTableCell(movement['out'].toString(), font, isArabic),
            _buildTableCell(movement['balance'].toString(), font, isArabic),
          ],
        ),
      );
      index++;
    }

    return rows;
  }

  static pw.Widget _buildFooter(bool isArabic, pw.Font arabicFont) {
    return pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text(
          'report_generated_by'.tr(),
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


  static String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static pw.Padding _buildTableHeaderCell(String text, pw.Font font, bool isArabic) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: font,
        ),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  static pw.Padding _buildTableCell(String text, pw.Font font, bool isArabic) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font),
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
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

  // دالة لإنشاء رابط تنزيل PDF
  static Future<String> generatePdfDownloadUrl({
    required List<QueryDocumentSnapshot> docs,
    required Map<String, String> productNames,
    required Map<String, int> productStocks,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> factoryData,
    required DateTime startDate,
    required DateTime endDate,
    bool isArabic = true,
  }) async {
    final pdf = await generateStockMovementsPdf(
      docs: docs,
      productNames: productNames,
      productStocks: productStocks,
      companyData: companyData,
      factoryData: factoryData,
      startDate: startDate,
      endDate: endDate,
      isArabic: isArabic,
    );

    final bytes = await pdf.save();
    final fileName = 'stock_movements_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = FirebaseStorage.instance.ref('stock_reports/$fileName');
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

    static Future<void> export(List<Map<String, dynamic>> data) async {
    //  نفّذ تصدير PDF هنا
    debugPrint("Exporting PDF with ${data.length} records...");
  }

}

