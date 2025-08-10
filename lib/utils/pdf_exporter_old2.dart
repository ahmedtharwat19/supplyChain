

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

/*   final jsonData = {
    'type': 'purchase_order',
    'id': orderId,
    'date': _formatOrderDate(orderData['orderDate']),
    'supplier': {
      'name': supplierData['name'] ?? 'N/A',
      'id': supplierData['id'] ?? 'N/A',
    },
    'company': {
      'name': isArabic ? companyData['nameAr'] : companyData['nameEn'],
      'tax_id': companyData['tax_id'] ?? 'N/A',
    },
    'items': (orderData['items'] as List).map((item) => {
      'itemId': item['itemId'] ?? 'N/A',
      'name': isArabic ? itemData['nameAr'] ?? 'N/A' : itemData['nameEn'] ?? 'N/A',
      'quantity': item['quantity'],
      'price': item['unitPrice'],
    }).toList(),
    'subtotal': orderData['totalAmount'],
    'tax': orderData['totalTax'],
    'total': orderData['totalAmountAfterTax'],
    'currency': orderData['currency'] ?? 'EGP', // قيمة افتراضية
  };

  return jsonEncode(jsonData); */

      // إنشاء محتوى نصي منظم للفاتورة
    /*  final invoiceContent = StringBuffer();
  
  invoiceContent.writeln('=== ${isArabic ? 'فاتورة شراء' : 'Purchase Order'} ===');
  invoiceContent.writeln('${isArabic ? 'رقم الفاتورة' : 'Invoice No'}: $orderId');
  invoiceContent.writeln('${isArabic ? 'التاريخ' : 'Date'}: ${_formatOrderDate(orderData['orderDate'])}');
  invoiceContent.writeln('${isArabic ? 'المورد' : 'Supplier'}: ${supplierData['name']}');
  invoiceContent.writeln('${isArabic ? 'الشركة' : 'Company'}: ${isArabic ? companyData['nameAr'] : companyData['nameEn']}');
  invoiceContent.writeln('---------------------------------');
  
  // إضافة العناصر
  invoiceContent.writeln('${isArabic ? 'العناصر' : 'Items'}:');
  final items = orderData['items'] as List? ?? [];
  for (final item in items) {
    final itemName = isArabic ? item['nameAr'] : item['nameEn'];
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
      'name': isArabic ? companyData['nameAr'] : companyData['nameEn'],
      'tax_id': companyData['tax_id'],
    },
      'items': (orderData['items'] as List)
          .map((item) => {
                'itemId': item['nameId'],
                'name': isArabic ? itemsData['nameAr'] : item['nameEn'],
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
        'name': isArabic ? companyData['nameAr'] : companyData['nameEn'],
      },
      'amount': orderData['totalAmountAfterTax'],
      'currency': orderData['currency'],
      'items': (orderData['items'] as List)
          .map((item) => {
                'itemId': item['nameId'],
                'name': isArabic ? itemsData['nameAr'] : item['nameEn'],
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
        'name': isArabic ? companyData['nameAr'] : companyData['nameEn'],
        'tax_id': companyData['tax_id'] ?? '',
      },
      'supplier': {
        'name': supplierData['name'],
        'id': supplierData['id'],
      },
      'items': (orderData['items'] as List)
          .map((item) => {
                'name': isArabic ? itemsData['nameAr'] : item['nameEn'],
                'quantity': item['quantity'],
                'price': item['unitPrice'],
              })
          .toList(),
    };

    return jsonEncode(jsonData); */

    final invoiceContent = '''
Invoice No: $orderId
Date: ${_formatOrderDate(orderData['orderDate'])}
Company: ${isArabic ? companyData['nameAr'] : companyData['nameEn']}
Supplier: ${supplierData['name']}
Total: ${orderData['totalAmountAfterTax']} ${orderData['currency']}
''';

    return invoiceContent;
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
      children: [
        pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes)),
            pw.Text(
              isArabic ? companyData['nameAr'] : companyData['nameEn'],
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
                isArabic ? companyData['nameAr'] : companyData['nameEn'],
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
                  isArabic ? companyData['nameAr'] : companyData['nameEn'],
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

/*   static List<pw.TableRow> _buildOrderItemsRows(
    List<dynamic> items,
    
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      final itemName = isArabic ? item['nameAr'] : item['nameEn'];
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
                  itemName ?? '',// (item[isArabic ? 'nameAr' : 'nameEn']?.toString() ?? ''),
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
${'company'.tr()}: ${companyData['nameAr']}
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

