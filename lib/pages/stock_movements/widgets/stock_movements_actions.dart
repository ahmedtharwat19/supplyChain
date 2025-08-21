import 'package:flutter/material.dart';

class StockMovementsTable extends StatefulWidget {
  final List<Map<String, dynamic>> movements;

  const StockMovementsTable({super.key, required this.movements});

  @override
  State<StockMovementsTable> createState() => _StockMovementsTableState();
}

class _StockMovementsTableState extends State<StockMovementsTable> {
  String? selectedCompany;
  String? selectedFactory;
  String? selectedItem;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // استخراج القيم المميزة للشركات / المصانع / الأصناف
    final companies = widget.movements
        .map((m) => m['company'] as String?)
        .where((e) => e != null)
        .toSet()
        .toList();

    final factories = widget.movements
        .map((m) => m['factory'] as String?)
        .where((e) => e != null)
        .toSet()
        .toList();

    final items = widget.movements
        .map((m) => m['item'] as String?)
        .where((e) => e != null)
        .toSet()
        .toList();

    // فلترة البيانات
    final filteredMovements = widget.movements.where((m) {
      final companyMatch = selectedCompany == null || m['company'] == selectedCompany;
      final factoryMatch = selectedFactory == null || m['factory'] == selectedFactory;
      final itemMatch = selectedItem == null || m['item'] == selectedItem;
      final searchMatch = searchQuery.isEmpty ||
          (m['company']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
          (m['factory']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
          (m['item']?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);

      return companyMatch && factoryMatch && itemMatch && searchMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // أدوات الفلترة
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                hint: const Text("اختر الشركة"),
                value: selectedCompany,
                items: companies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c!)))
                    .toList(),
                onChanged: (val) => setState(() => selectedCompany = val),
              ),
              DropdownButton<String>(
                hint: const Text("اختر المصنع"),
                value: selectedFactory,
                items: factories
                    .map((f) => DropdownMenuItem(value: f, child: Text(f!)))
                    .toList(),
                onChanged: (val) => setState(() => selectedFactory = val),
              ),
              DropdownButton<String>(
                hint: const Text("اختر الصنف"),
                value: selectedItem,
                items: items
                    .map((i) => DropdownMenuItem(value: i, child: Text(i!)))
                    .toList(),
                onChanged: (val) => setState(() => selectedItem = val),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "بحث",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
              ),
              IconButton(
                tooltip: "إعادة التعيين",
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    selectedCompany = null;
                    selectedFactory = null;
                    selectedItem = null;
                    searchQuery = '';
                  });
                },
              )
            ],
          ),
        ),

        // جدول الحركات
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  headingRowColor:
                      WidgetStateProperty.all(Colors.blueGrey.shade50),
                  columns: const [
                    DataColumn(label: Text("الشركة")),
                    DataColumn(label: Text("المصنع")),
                    DataColumn(label: Text("الصنف")),
                    DataColumn(label: Text("الكمية")),
                    DataColumn(label: Text("التاريخ")),
                  ],
                  rows: filteredMovements.map((m) {
                    return DataRow(
                      cells: [
                        DataCell(Text(m['company'] ?? '')),
                        DataCell(Text(m['factory'] ?? '')),
                        DataCell(Text(m['item'] ?? '')),
                        DataCell(Text("${m['quantity'] ?? ''}")),
                        DataCell(Text(m['date'] ?? '')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
