import 'package:flutter/foundation.dart';
import '../services/movement_utils.dart';
import '../services/stock_pdf_exporter.dart';

/// Controller لإدارة حالة صفحة الحركات
class StockMovementsController extends ChangeNotifier {
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;

  List<Map<String, dynamic>> movements = [];
  Map<String, dynamic> activeFilters = {};

  /// تحميل البيانات من السيرفس
  Future<void> loadMovements() async {
    try {
      isLoading = true;
      hasError = false;
      notifyListeners();

      movements = await MovementUtils.fetchMovements(filters: activeFilters);

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      hasError = true;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// تطبيق الفلاتر وإعادة تحميل البيانات
  void applyFilters(Map<String, dynamic> filters) {
    activeFilters = filters;
    loadMovements();
  }

  /// تصدير PDF
  Future<void> exportPdf() async {
    await StockPdfExporter.export(movements);
  }

  /// تصدير Excel (ممكن تضيفه لاحقاً)
  Future<void> exportExcel() async {
    await MovementUtils.exportExcel(movements);
  }
}
