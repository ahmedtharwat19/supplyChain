// lib/utils/movement_utils.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MovementUtils {
  static Map<String, dynamic> getMovementTypeInfo(String type, int quantity) {
    switch (type) {
      case 'purchase':
        return {
          'in': quantity,
          'out': 0,
          'type_text': 'purchase'.tr(),
        };
      case 'manufacturing':
        return {
          'in': 0,
          'out': quantity,
          'type_text': 'manufacturing'.tr(),
        };
      case 'transfer_in':
        return {
          'in': quantity,
          'out': 0,
          'type_text': 'transfer_in'.tr(),
        };
      case 'transfer_out':
        return {
          'in': 0,
          'out': quantity,
          'type_text': 'transfer_out'.tr(),
        };
      case 'adjustment':
        return {
          'in': quantity > 0 ? quantity : 0,
          'out': quantity < 0 ? -quantity : 0,
          'type_text': 'adjustment'.tr(),
        };
      default:
        return {
          'in': 0,
          'out': 0,
          'type_text': 'unknown'.tr(),
        };
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static String getMovementTypeDisplay(String type) {
    switch (type) {
      case 'purchase':
        return 'purchase'.tr();
      case 'manufacturing':
        return 'manufacturing'.tr();
      case 'transfer_in':
        return 'transfer_in'.tr();
      case 'transfer_out':
        return 'transfer_out'.tr();
      case 'adjustment':
        return 'adjustment'.tr();
      default:
        return 'unknown'.tr();
    }
  }
    static Future<List<Map<String, dynamic>>> fetchMovements({
    Map<String, dynamic>? filters,
  }) async {
    //  اربط هنا الـ API أو DB
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      {
        "date": DateTime.now().toString(),
        "item": "صنف تجريبي",
        "movementType": "إضافة",
        "quantity": 10,
        "user": "Admin",
      },
    ];
  }

  static Future<void> exportExcel(List<Map<String, dynamic>> data) async {
    //  نفّذ تصدير Excel هنا
    debugPrint("Exporting Excel with ${data.length} records...");
  }
  
}
