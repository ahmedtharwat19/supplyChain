import 'package:flutter/material.dart';

/// Widget خاص بالفلاتر
class StockMovementsFilters extends StatefulWidget {
  final Function(Map<String, dynamic>) onFilterChanged;

  const StockMovementsFilters({
    super.key,
    required this.onFilterChanged,
  });

  @override
  State<StockMovementsFilters> createState() => _StockMovementsFiltersState();
}

class _StockMovementsFiltersState extends State<StockMovementsFilters> {
  DateTime? fromDate;
  DateTime? toDate;
  String? selectedItem;
  String? selectedMovementType;

  final List<String> movementTypes = ["إضافة", "صرف", "تحويل"];

  /// اختيار تاريخ
  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final filters = {
      "fromDate": fromDate,
      "toDate": toDate,
      "item": selectedItem,
      "movementType": selectedMovementType,
    };
    widget.onFilterChanged(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: [
            /// من تاريخ
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("من: "),
                TextButton(
                  onPressed: () => _pickDate(context, true),
                  child: Text(
                    fromDate != null
                        ? "${fromDate!.day}/${fromDate!.month}/${fromDate!.year}"
                        : "اختر",
                  ),
                ),
              ],
            ),

            /// إلى تاريخ
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("إلى: "),
                TextButton(
                  onPressed: () => _pickDate(context, false),
                  child: Text(
                    toDate != null
                        ? "${toDate!.day}/${toDate!.month}/${toDate!.year}"
                        : "اختر",
                  ),
                ),
              ],
            ),

            /// نوع الحركة
            DropdownButton<String>(
              value: selectedMovementType,
              hint: const Text("نوع الحركة"),
              items: movementTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                setState(() => selectedMovementType = val);
                _applyFilters();
              },
            ),

            /// الصنف (هنا placeholder، تقدر تجيب الأصناف من DB)
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: "الصنف",
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  selectedItem = val;
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
