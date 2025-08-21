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
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();

    final factories = widget.movements
        .map((m) => m['factory'] as String?)
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();

    final items = widget.movements
        .map((m) => m['item'] as String?)
        .where((e) => e != null && e.isNotEmpty)
        .toSet()
        .toList();

    // فلترة البيانات
    final filteredMovements = widget.movements.where((m) {
      final companyMatch =
          selectedCompany == null || m['company'] == selectedCompany;
      final factoryMatch =
          selectedFactory == null || m['factory'] == selectedFactory;
      final itemMatch = selectedItem == null || m['item'] == selectedItem;
      final searchMatch = searchQuery.isEmpty ||
          (m['company']?.toString().toLowerCase() ?? '')
              .contains(searchQuery.toLowerCase()) ||
          (m['factory']?.toString().toLowerCase() ?? '')
              .contains(searchQuery.toLowerCase()) ||
          (m['item']?.toString().toLowerCase() ?? '')
              .contains(searchQuery.toLowerCase());

      return companyMatch && factoryMatch && itemMatch && searchMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// أدوات الفلترة
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildDropdown(
                label: "الشركة",
                value: selectedCompany,
                items: companies,
                onChanged: (val) => setState(() => selectedCompany = val),
              ),
              _buildDropdown(
                label: "المصنع",
                value: selectedFactory,
                items: factories,
                onChanged: (val) => setState(() => selectedFactory = val),
              ),
              _buildDropdown(
                label: "الصنف",
                value: selectedItem,
                items: items,
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
              ),
            ],
          ),
        ),

        /// جدول الحركات
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
                    DataColumn(label: Text("التاريخ")),
                    DataColumn(label: Text("الشركة")),
                    DataColumn(label: Text("المصنع")),
                    DataColumn(label: Text("الصنف")),
                    DataColumn(label: Text("الكمية")),
                    DataColumn(label: Text("نوع الحركة")),
                  ],
                  rows: filteredMovements.map((m) {
                    return DataRow(
                      cells: [
                        DataCell(Text(m['date']?.toString() ?? '')),
                        DataCell(Text(m['company']?.toString() ?? '')),
                        DataCell(Text(m['factory']?.toString() ?? '')),
                        DataCell(Text(m['item']?.toString() ?? '')),
                        DataCell(Text(m['quantity']?.toString() ?? '')),
                        DataCell(Text(m['movement_type']?.toString() ?? '')),
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

  /// ويدجت Dropdown لإعادة الاستخدام
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String?> items,
    required void Function(String?) onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        onChanged: onChanged,
        items: items
            .where((e) => e != null)
            .map((e) => DropdownMenuItem(value: e!, child: Text(e)))
            .toList(),
      ),
    );
  }
}
