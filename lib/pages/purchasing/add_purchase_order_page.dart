import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_scaffold.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  final String selectedCompany;
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  String? factoryId;
  DateTime orderDate = DateTime.now();
  bool isLoading = false;
  List<Map<String, dynamic>> allFactories = [];

  @override
  void initState() {
    super.initState();
    _loadFactories();
    if (widget.editOrderId != null) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadFactories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies/${widget.selectedCompany}/factories')
        .get();
    setState(() {
      allFactories =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _loadExistingOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('companies/${widget.selectedCompany}/purchase_orders')
        .doc(widget.editOrderId)
        .get();
    final data = doc.data();
    if (!mounted || data == null) return;

    setState(() {
      _supplierController.text = data['supplierName'] ?? '';
      items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => {'name': e['name'], 'qty': e['qty']})
          .toList();
      factoryId = (data['factoryIds'] as List<dynamic>?)?.cast<String>().first;
      final ts = data['createdAt'] as Timestamp?;
      if (ts != null) orderDate = ts.toDate();
    });
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_itemQtyController.text.trim());
    if (name.isEmpty || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('invalid_item'.tr())));
      return;
    }
    setState(() {
      items.add({'name': name, 'qty': qty});
      _itemNameController.clear();
      _itemQtyController.clear();
    });
  }

  Future<void> _saveOrder() async {
    if (items.isEmpty || _supplierController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('missing_fields'.tr())));
      return;
    }

    setState(() => isLoading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('companies/${widget.selectedCompany}/purchase_orders');
      final data = {
        'supplierName': _supplierController.text.trim(),
        'items': items,
        'factoryIds': factoryId != null ? [factoryId] : [],
        'createdAt': orderDate,
        'isConfirmed': false,
        'companyId': widget.selectedCompany,
      };

      if (widget.editOrderId != null) {
        await ref.doc(widget.editOrderId).update(data);
      } else {
        await ref.add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('order_saved'.tr())));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'save_error'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.editOrderId != null
          ? 'edit_purchase_order'.tr()
          : 'new_purchase_order'.tr(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _supplierController,
                      decoration: InputDecoration(labelText: 'supplier'.tr()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _itemNameController,
                            decoration: InputDecoration(labelText: 'item'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _itemQtyController,
                            decoration: InputDecoration(labelText: 'qty'.tr()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addItem,
                          child: Text('add'.tr()),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: items
                          .map((e) => Chip(
                                label: Text('${e['name']} x${e['qty']}'),
                                onDeleted: () => setState(() {
                                  items.remove(e);
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: factoryId,
                      items: allFactories
                          .map((f) => DropdownMenuItem<String>(
                                value: f['id'],
                                child: Text(f['name_ar'] ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => factoryId = v),
                      decoration: InputDecoration(labelText: 'factory'.tr()),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(DateFormat('dd/MM/yyyy').format(orderDate)),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: orderDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null && mounted) {
                          setState(() => orderDate = selected);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveOrder,
                      child: Text('save'.tr()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
