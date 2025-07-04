import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/select_item_dialog.dart';
import '../../widgets/select_supplier_dialog.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String? selectedCompany;
  final String? editOrderId;

  const AddPurchaseOrderPage({
    super.key,
    required this.selectedCompany,
    this.editOrderId,
  });

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
  double _totalTax = 0.0;
  double _totalAmount = 0.0;
  bool _isSaving = false;
  bool _isConfirmed = false;

  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _dateController = TextEditingController();
    if (widget.editOrderId != null) {
      _loadOrderData();
    }
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

  Future<void> _loadOrderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companies/${widget.selectedCompany}/purchase_orders')
        .doc(widget.editOrderId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _supplierId = data['supplierId'];
        _supplierName = data['supplierName'] ?? data['supplierId'];
        _orderDate = (data['orderDate'] as Timestamp?)?.toDate();
        _selectedItems.clear();
        _selectedItems.addAll(List<Map<String, dynamic>>.from(data['items'] ?? []));
        _isConfirmed = data['confirmed'] ?? false;
        _calculateTotals();
        _dateController.text = _orderDate?.toLocal().toString().split(' ')[0] ?? '';
      });
    }
  }

  void _calculateTotals() {
    _totalBeforeTax = 0.0;
    _totalTax = 0.0;

    for (var item in _selectedItems) {
      final qty = item['quantity'] ?? 0;
      final price = item['unitPrice'] ?? 0.0;
      final taxPercent = item['taxPercent'] ?? 0.0;

      final subtotal = qty * price;
      final taxAmount = subtotal * (taxPercent / 100);

      _totalBeforeTax += subtotal;
      _totalTax += taxAmount;
    }

    _totalAmount = _totalBeforeTax + _totalTax;
  }

  Future<void> _showAddItemToOrderDialog() async {
    final selectedItem = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectItemDialog(companyId: widget.selectedCompany!),
    );

    if (selectedItem != null) {
      setState(() {
        final existingIndex = _selectedItems.indexWhere((item) => item['id'] == selectedItem['id']);
        if (existingIndex != -1) {
          _selectedItems[existingIndex]['quantity'] = (_selectedItems[existingIndex]['quantity'] ?? 0) + 1;
        } else {
          _selectedItems.add({
            'id': selectedItem['id'],
            'name': selectedItem['name'],
            'unitPrice': selectedItem['unitPrice'],
            'quantity': 1,
            'taxPercent': 0.0,
          });
        }
        _calculateTotals();
      });
    }
  }

  Future<void> _showSelectSupplierDialog() async {
    final selectedSupplier = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectSupplierDialog(companyId: widget.selectedCompany!),
    );

    if (selectedSupplier != null) {
      setState(() {
        _supplierId = selectedSupplier['id'];
        _supplierName = selectedSupplier['name'];
      });
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف أمر الشراء؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('companies/${widget.selectedCompany}/purchase_orders')
          .doc(widget.editOrderId)
          .delete();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _saveOrder() async {
    if (_supplierId == null || _selectedItems.isEmpty || widget.selectedCompany == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول وإضافة أصناف')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final collection = FirebaseFirestore.instance
          .collection('companies/${widget.selectedCompany!}/purchase_orders');

      final data = {
        'supplierId': _supplierId,
        'supplierName': _supplierName,
        'items': _selectedItems,
        'totalBeforeTax': _totalBeforeTax,
        'tax': _totalTax,
        'totalAmount': _totalAmount,
        'orderDate': _orderDate != null ? Timestamp.fromDate(_orderDate!) : Timestamp.now(),
        'createdBy': _userId,
        'confirmed': false,
      };

      if (widget.editOrderId == null) {
        data['createdAt'] = Timestamp.now();
        await collection.add(data);
      } else {
        await collection.doc(widget.editOrderId).update(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ أمر الشراء بنجاح')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editOrderId != null ? 'تعديل أمر شراء' : 'إضافة أمر شراء'),
        actions: [
          if (widget.editOrderId != null && !_isConfirmed)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteOrder,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InkWell(
              onTap: _isConfirmed ? null : _showSelectSupplierDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'المورد',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _supplierName ?? 'اضغط للاختيار',
                  style: TextStyle(
                    color: _supplierName == null ? Colors.grey.shade600 : Colors.black,
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
              onTap: _isConfirmed
                  ? null
                  : () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _orderDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _orderDate = pickedDate;
                          _dateController.text = _orderDate!.toLocal().toString().split(' ')[0];
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConfirmed ? null : _showAddItemToOrderDialog,
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
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    const Text('الكمية:'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['quantity'].toString(),
                                        keyboardType: TextInputType.number,
                                        enabled: !_isConfirmed,
                                        onChanged: (value) {
                                          final qty = int.tryParse(value) ?? 1;
                                          setState(() {
                                            item['quantity'] = qty;
                                            _calculateTotals();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text('السعر:'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['unitPrice'].toString(),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        enabled: !_isConfirmed,
                                        onChanged: (value) {
                                          final price = double.tryParse(value) ?? 0.0;
                                          setState(() {
                                            item['unitPrice'] = price;
                                            _calculateTotals();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('نسبة الضريبة %:'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['taxPercent']?.toString() ?? '0',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        enabled: !_isConfirmed,
                                        onChanged: (value) {
                                          final tax = double.tryParse(value) ?? 0.0;
                                          setState(() {
                                            item['taxPercent'] = tax;
                                            _calculateTotals();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'الإجمالي: ${(item['quantity'] * item['unitPrice']).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (!_isConfirmed)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedItems.removeAt(index);
                                          _calculateTotals();
                                        });
                                      },
                                    ),
                                  ),
                              ],
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || _isConfirmed) ? null : _saveOrder,
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
