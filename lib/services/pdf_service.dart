/* import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class PdfService {
  static Future<pw.Font> _loadFont(String fontPath) async {
    if (kIsWeb) {
      final response = await http.get(Uri.parse(fontPath));
      if (response.statusCode == 200) {
        return pw.Font.ttf(response.bodyBytes);
      }
      throw Exception('Failed to load font from web');
    } else {
      final fontData = await rootBundle.load(fontPath);
      return pw.Font.ttf(fontData);
    }
  }

  static Future<File> generateAndSavePdf({
    required String title,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await _loadFont('assets/fonts/Cairo-Regular.ttf');

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.Header(level: 0, child: pw.Text(title)),
                pw.Table.fromTextArray(
                  context: context,
                  data: [
                    ['Item', 'Quantity', 'Price'],
                    ...items.map((item) => [
                          item['name'],
                          item['quantity'].toString(),
                          item['price'].toString(),
                        ])
                  ],
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 20),
                  child: pw.Text('Total: $totalAmount'),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$title.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> sharePdf(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Purchase Order',
      subject: 'PDF Export',
    );
  }
} */