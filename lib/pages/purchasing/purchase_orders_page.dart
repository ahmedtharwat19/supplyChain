import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../utils/pdf_exporter.dart';
import '../../widgets/company_selector.dart';

class PurchaseOrdersPage extends StatefulWidget {
  final String? userName;

  const PurchaseOrdersPage({super.key, this.userName});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String? selectedCompany;
  String? _userId;
  String supplierFilter = '';
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });
  }

Future<void> deleteOrder(String orderId) async {
  if (selectedCompany == null) return;

  final docRef = FirebaseFirestore.instance
      .collection('companies/$selectedCompany/purchase_orders')
      .doc(orderId);

  final doc = await docRef.get();
  if (!mounted) return; // ✅ Safety check

  if (doc.exists && !(doc.data()?['isConfirmed'] ?? false)) {
    await docRef.delete();
    if (!mounted) return; // ✅ Check again after await
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف أمر الشراء بنجاح.')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يمكن حذف أمر مؤكد.')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوامر الشراء'),
        bottom: widget.userName != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'مرحبًا، ${widget.userName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              )
            : null,
      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CompanySelector(
                    userId: _userId!,
                    onCompanySelected: (companyId) {
                      setState(() => selectedCompany = companyId);
                    },
                  ),
                ),
                if (selectedCompany == null)
                  const Expanded(
                    child: Center(child: Text('يرجى اختيار الشركة لعرض أوامر الشراء')),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'فلترة حسب المورد',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setState(() => supplierFilter = value);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.date_range),
                                tooltip: "فلترة بالتاريخ",
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null && mounted) {
                                    setState(() {
                                      startDate = picked.start;
                                      endDate = picked.end;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('companies/$selectedCompany/purchase_orders')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                              }

                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text('لا توجد أوامر شراء مسجلة.'));
                              }

                              final allOrders = snapshot.data!.docs;
                              final orders = allOrders.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final supplier =
                                    (data['supplierId'] ?? '').toString().toLowerCase();
                                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                                final matchesSupplier =
                                    supplier.contains(supplierFilter.toLowerCase());
                                final matchesDate = startDate == null ||
                                    endDate == null ||
                                    (createdAt != null &&
                                        !createdAt.isBefore(startDate!) &&
                                        !createdAt.isAfter(endDate!.add(const Duration(days: 1))));
                                return matchesSupplier && matchesDate;
                              }).toList();

                              if (orders.isEmpty) {
                                return const Center(child: Text('لا توجد أوامر مطابقة للفلاتر.'));
                              }

                              return ListView.builder(
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  final data = order.data() as Map<String, dynamic>;
                                  final createdAt =
                                      (data['createdAt'] as Timestamp?)?.toDate();
                                  final isConfirmed = data['isConfirmed'] ?? false;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: ListTile(
                                      title: Text('طلب #${order.id}'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('المورد: ${data['supplierId']}'),
                                          Text('الإجمالي: ${data['totalAmount']?.toStringAsFixed(2) ?? 'N/A'} ل.إ'),
                                          if (createdAt != null)
                                            Text('التاريخ: ${createdAt.toLocal().toString().split(' ').first}'),
                                          Text('الحالة: ${isConfirmed ? 'مؤكد' : 'غير مؤكد'}'),
                                        ],
                                      ),
                                      trailing: Wrap(
                                        spacing: 8,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.picture_as_pdf),
                                            tooltip: "تصدير PDF",
                                            onPressed: () async {
                                              final companyDoc = await FirebaseFirestore.instance
                                                  .collection('companies').doc(selectedCompany).get();
                                              final supplierDoc = await FirebaseFirestore.instance
                                                  .collection('vendors').doc(data['supplierId']).get();

                                              final pdf = await generatePurchaseOrderPdf(
                                                orderId: order.id,
                                                orderData: data,
                                                supplierData: supplierDoc.data() ??
                                                    {'name': data['supplierId'], 'company': ''},
                                                companyData: companyDoc.data() ??
                                                    {'name_ar': '---', 'name_en': '---', 'logo_base64': ''},
                                              );
                                              await Printing.layoutPdf(
                                                  onLayout: (format) async => pdf.save());
                                            },
                                          ),
                                          if (!isConfirmed) ...[
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              tooltip: "تعديل الطلب",
                                              onPressed: () {
                                                context.push(
                                                  '/add-purchase-order?companyId=$selectedCompany&editOrderId=${order.id}',
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              tooltip: "حذف الطلب",
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('تأكيد الحذف'),
                                                    content: const Text('هل أنت متأكد من حذف هذا الطلب؟'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx, false),
                                                        child: const Text('إلغاء'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: const Text('حذف'),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  await deleteOrder(order.id);
                                                }
                                              },
                                            ),
                                          ]
                                        ],
                                      ),
                                      onTap: () {
                                        context.push(
                                          '/purchase-order-detail?companyId=$selectedCompany&orderId=${order.id}',
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedCompany == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يرجى اختيار الشركة أولًا')),
            );
            return;
          }
          context.push('/add-purchase-order?companyId=$selectedCompany');
        },
        tooltip: 'إضافة أمر شراء',
        child: const Icon(Icons.add),
      ),
    );
  }
}
