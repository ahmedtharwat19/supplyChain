import 'package:flutter/foundation.dart';
import '../services/movement_utils.dart';
import '../services/stock_pdf_exporter.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

/// Controller لإدارة حالة صفحة الحركات
class StockMovementsController extends ChangeNotifier {
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;

  List<Map<String, dynamic>> movements = [];
  Map<String, dynamic> activeFilters = {};

  // إضافة الدوال الجديدة المطلوبة
  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> factories = [];
  List<Map<String, dynamic>> products = [];
  Map<String, int> productStocks = {};
  Map<String, String> productNames = {};
  
  String? selectedCompanyId;
  String? selectedFactoryId;
  String? selectedProductId;
  DateTime? startDate;
  DateTime? endDate;
  String sortOrder = 'desc';

  /// تحميل البيانات من Firestore
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

  /// تحميل الشركات
  Future<void> loadCompanies() async {
    // تنفيذ منطق تحميل الشركات
  }

  /// تحميل المصانع
  Future<void> loadFactories() async {
    // تنفيذ منطق تحميل المصانع
  }

  /// تحميل المنتجات
  Future<void> loadProducts() async {
    // تنفيذ منطق تحميل المنتجات
  }

  /// تصدير PDF باستخدام البيانات الحالية
  Future<void> exportPdf() async {
    try {
      await StockPdfExporter.export(movements);
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
    }
  }

  /// تصدير Excel
  Future<void> exportExcel() async {
    await MovementUtils.exportExcel(movements);
  }
}