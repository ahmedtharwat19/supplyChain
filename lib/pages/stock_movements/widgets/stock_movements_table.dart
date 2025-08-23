import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovementsTable extends StatefulWidget {
  const StockMovementsTable({super.key});

  @override
  State<StockMovementsTable> createState() => _StockMovementsTableState();
}

class _StockMovementsTableState extends State<StockMovementsTable> {
  String? selectedCompany;
  String? selectedFactory;
  String? selectedItem;
  String searchText = '';

  @override
  Widget build(BuildContext context) {
    final movementsRef = FirebaseFirestore.instance.collection('stock_movements');

    return Scaffold(
      appBar: AppBar(
        title: const Text("حركات المخزون"),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: movementsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("حدث خطأ أثناء تحميل البيانات"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final companyMatch = selectedCompany == null || data['company'] == selectedCompany;
                  final factoryMatch = selectedFactory == null || data['factory'] == selectedFactory;
                  final itemMatch = selectedItem == null || data['item'] == selectedItem;
                  final searchMatch = searchText.isEmpty ||
                      (data['item'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(searchText.toLowerCase());

                  return companyMatch && factoryMatch && itemMatch && searchMatch;
                }).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                      border: TableBorder.all(color: Colors.grey),
                      columns: const [
                        DataColumn(label: Text("التاريخ")),
                        DataColumn(label: Text("الشركة")),
                        DataColumn(label: Text("المصنع")),
                        DataColumn(label: Text("الصنف")),
                        DataColumn(label: Text("الكمية")),
                        DataColumn(label: Text("الحركة")),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DataRow(cells: [
                          DataCell(Text((data['date'] ?? '').toString())),
                          DataCell(Text((data['company'] ?? '').toString())),
                          DataCell(Text((data['factory'] ?? '').toString())),
                          DataCell(Text((data['item'] ?? '').toString())),
                          DataCell(Text((data['quantity'] ?? '').toString())),
                          DataCell(Text((data['movement_type'] ?? '').toString())),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ويدجت الفلاتر
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildDropdown(
            label: "الشركة",
            value: selectedCompany,
            onChanged: (val) => setState(() => selectedCompany = val),
            items: const ["شركة 1", "شركة 2", "شركة 3"],
          ),
          _buildDropdown(
            label: "المصنع",
            value: selectedFactory,
            onChanged: (val) => setState(() => selectedFactory = val),
            items: const ["مصنع 1", "مصنع 2"],
          ),
          _buildDropdown(
            label: "الصنف",
            value: selectedItem,
            onChanged: (val) => setState(() => selectedItem = val),
            items: const ["صنف 1", "صنف 2", "صنف 3"],
          ),
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                labelText: "بحث عن صنف",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => searchText = val),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                selectedCompany = null;
                selectedFactory = null;
                selectedItem = null;
                searchText = '';
              });
            },
            child: const Text("إعادة تعيين"),
          ),
        ],
      ),
    );
  }

  /// ويدجت الـ Dropdown جاهز لإعادة الاستخدام
  Widget _buildDropdown({
    required String label,
    required String? value,
    required void Function(String?) onChanged,
    required List<String> items,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        initialValue: value,
        onChanged: onChanged,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }
}
