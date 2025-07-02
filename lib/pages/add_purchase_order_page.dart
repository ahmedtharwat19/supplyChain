import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/select_item_dialog.dart';
import '../widgets/select_supplier_dialog.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;

  const AddPurchaseOrderPage({super.key, required this.selectedCompany});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  String? _userId;
  String? _supplierId;
  String? _supplierName;
  DateTime? _orderDate;
  final List<Map<String, dynamic>> _selectedItems = [];
  double _totalBeforeTax = 0.0;
  final double _taxPercentage = 0.14;
  double _totalTax = 0.0;
  double _totalAmount = 0.0;
  bool _isSaving = false;

  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _dateController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });
  }

  void _calculateTotals() {
    _totalBeforeTax = _selectedItems.fold(
      0.0,
      (total, item) =>
          total + ((item['quantity'] ?? 0) * (item['unitPrice'] ?? 0.0)),
    );
    _totalTax = _totalBeforeTax * _taxPercentage;
    _totalAmount = _totalBeforeTax + _totalTax;
  }

  Future<void> _showAddItemToOrderDialog() async {
    final selectedItem = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          SelectItemDialog(companyId: widget.selectedCompany!),
    );

    if (selectedItem != null) {
      setState(() {
        final existingIndex = _selectedItems
            .indexWhere((item) => item['id'] == selectedItem['id']);
        if (existingIndex != -1) {
          _selectedItems[existingIndex]['quantity'] =
              (_selectedItems[existingIndex]['quantity'] ?? 0) + 1;
        } else {
          _selectedItems.add({
            'id': selectedItem['id'],
            'name': selectedItem['name'],
            'unitPrice': selectedItem['unitPrice'],
            'quantity': 1,
          });
        }
        _calculateTotals();
      });
    }
  }

  Future<void> _showSelectSupplierDialog() async {
    final selectedSupplier = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          SelectSupplierDialog(companyId: widget.selectedCompany!),
    );

    if (selectedSupplier != null) {
      setState(() {
        _supplierId = selectedSupplier['id'];
        _supplierName = selectedSupplier['name'];
      });
    }
  }

  Future<void> _saveOrder() async {
    if (_supplierId == null ||
        _selectedItems.isEmpty ||
        widget.selectedCompany == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول وإضافة أصناف')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('companies/${widget.selectedCompany!}/purchase_orders')
          .add({
        'supplierId': _supplierId,
        'items': _selectedItems
            .map((item) => {
                  'id': item['id'],
                  'name': item['name'],
                  'quantity': item['quantity'],
                  'unitPrice': item['unitPrice'],
                })
            .toList(),
        'totalBeforeTax': _totalBeforeTax,
        'tax': _totalTax,
        'totalAmount': _totalAmount,
        'createdAt': Timestamp.now(),
        'orderDate': _orderDate != null
            ? Timestamp.fromDate(_orderDate!)
            : Timestamp.now(),
        'createdBy': _userId,
      });

      if (!mounted) return;
      Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة أمر الشراء بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _updateItemQuantity(int index, int quantity) {
    if (quantity < 1) return;
    setState(() {
      _selectedItems[index]['quantity'] = quantity;
      _calculateTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة أمر شراء'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InkWell(
              onTap: _showSelectSupplierDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'المورد',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _supplierName ?? 'اضغط للاختيار',
                  style: TextStyle(
                    color: _supplierName == null
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'تاريخ الطلب',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              controller: _dateController,
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _orderDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    _orderDate = pickedDate;
                    _dateController.text =
                        _orderDate!.toLocal().toString().split(' ')[0];
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddItemToOrderDialog,
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedItems.isEmpty
                  ? const Center(child: Text('لم تتم إضافة أصناف بعد'))
                  : ListView.builder(
                      itemCount: _selectedItems.length,
                      itemBuilder: (context, index) {
                        final item = _selectedItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(item['name']),
                            subtitle:
                                Text('السعر للوحدة: ${item['unitPrice']} ج.م'),
                            trailing: SizedBox(
                              width: 140,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      int currentQty = item['quantity'] ?? 1;
                                      if (currentQty > 1) {
                                        _updateItemQuantity(
                                            index, currentQty - 1);
                                      }
                                    },
                                  ),
                                  Text('${item['quantity']}'),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      int currentQty = item['quantity'] ?? 1;
                                      _updateItemQuantity(
                                          index, currentQty + 1);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _selectedItems.removeAt(index);
                                        _calculateTotals();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الإجمالي: ${_totalAmount.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveOrder,
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
