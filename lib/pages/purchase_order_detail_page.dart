import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../utils/pdf_exporter.dart';

class PurchaseOrderDetailPage extends StatefulWidget {
  final String companyId;
  final String orderId;

  const PurchaseOrderDetailPage({
    super.key,
    required this.companyId,
    required this.orderId,
  });

  @override
  State<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState extends State<PurchaseOrderDetailPage> {
  Map<String, dynamic>? orderData;
  Map<String, dynamic>? supplierData;
  Map<String, dynamic>? companyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('companies/${widget.companyId}/purchase_orders')
          .doc(widget.orderId)
          .get();

      final order = orderSnap.data();
      if (order == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order not found.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Fetch supplier data from the general 'vendors' collection
      final supplierSnap = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId']) // Assuming supplierId in orderData is the doc ID in 'vendors'
          .get();

      final companySnap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (!mounted) return;

      setState(() {
        orderData = order;
        supplierData = supplierSnap.data();
        companyData = companySnap.data();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching order data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order details: $e')),
        );
        Navigator.pop(context);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || orderData == null || supplierData == null || companyData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final createdAt = (orderData!['createdAt'] as Timestamp?)?.toDate();
    final formattedDate =
        createdAt != null ? DateFormat('yyyy/MM/dd').format(createdAt) : '---';

    final items = List<Map<String, dynamic>>.from(orderData!['items'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب شراء #${widget.orderId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير إلى PDF',
            onPressed: () async {
              final pdf = await generatePurchaseOrderPdf(
                orderId: widget.orderId,
                orderData: orderData!,
                supplierData: supplierData!,
                companyData: companyData!,
              );

              await Printing.layoutPdf(onLayout: (format) async => pdf.save());
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 🏢 معلومات الشركة والمورد
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyData!['name_ar'] ?? companyData!['name_en'] ?? 'اسم الشركة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('المورد: ${supplierData!['name'] ?? 'N/A'} - ${supplierData!['company'] ?? 'N/A'}'),
                    Text('التاريخ: $formattedDate'),
                  ],
                ),
              ),
            ),
            const Divider(),

            // 🛒 المنتجات
            const Text('تفاصيل الأصناف:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('لا توجد أصناف في أمر الشراء هذا.')
            else
              ...items.map((item) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item['name'] ?? ''),
                      subtitle: Text(
                          'الكمية: ${item['quantity']} × السعر: ${item['unitPrice']?.toStringAsFixed(2)} ج.م\n'
                          'النوع: ${_getItemTypeDisplayName(item['type'] ?? 'N/A')}'),
                      trailing: Text(
                        'المجموع: ${((item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0)).toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),

            const Divider(),

            // 💰 الإجماليات
            ListTile(
              title: const Text('الإجمالي قبل الضريبة'),
              trailing: Text(
                  '${(orderData!['totalBeforeTax'] ?? 0).toStringAsFixed(2)} ج.م'),
            ),
            ListTile(
              title: const Text('الضريبة'),
              trailing:
                  Text('${(orderData!['tax'] ?? 0).toStringAsFixed(2)} ج.م'),
            ),
            ListTile(
              title: const Text('الإجمالي الكلي'),
              trailing: Text(
                  '${(orderData!['totalAmount'] ?? 0).toStringAsFixed(2)} ج.م'),
            ),

            const Divider(),

            // 💳 شروط الدفع
            ListTile(
              title: const Text('شروط الدفع'),
              subtitle: Text(orderData!['paymentTerms'] ?? 'غير محددة'),
            ),

            const SizedBox(height: 20),

            // 🖨 زر إضافي للطباعة
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('طباعة / تصدير PDF'),
                onPressed: () async {
                  final pdf = await generatePurchaseOrderPdf(
                    orderId: widget.orderId,
                    orderData: orderData!,
                    supplierData: supplierData!,
                    companyData: companyData!,
                  );
                  await Printing.layoutPdf(
                      onLayout: (format) async => pdf.save());
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}