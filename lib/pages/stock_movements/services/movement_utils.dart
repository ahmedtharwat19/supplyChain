// lib/utils/movement_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('stock_movements')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (m, _) => m,
          );

      // تطبيق الفلاتر
      if (filters != null) {
        if (filters['companyId'] != null) {
          query = query.where('companyId', isEqualTo: filters['companyId']);
        }
        if (filters['factoryId'] != null) {
          query = query.where('factoryId', isEqualTo: filters['factoryId']);
        }
        if (filters['itemId'] != null) {
          query = query.where('itemId', isEqualTo: filters['itemId']);
        }
        if (filters['fromDate'] != null && filters['toDate'] != null) {
          query = query
              .where('date', isGreaterThanOrEqualTo: filters['fromDate'])
              .where('date', isLessThanOrEqualTo: filters['toDate']);
        }
        if (filters['movementType'] != null) {
          query = query.where('type', isEqualTo: filters['movementType']);
        }
      }

      final querySnapshot = await query.get();
      final movements = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['date']?.toString(),
          'company': data['nameAr'] ?? data['companyId'],
          'factory': data['nameAr'] ?? data['factoryId'],
          'item': data['nameAr'] ?? data['itemId'],
          'quantity': data['quantity']?.toString(),
          'movementType': getMovementTypeDisplay(data['type'] ?? ''),
          'user': data['displayName'] ?? data['userId'],
        };
      }).toList();

      return movements;
    } catch (e) {
      debugPrint('Error fetching movements: $e');
      rethrow;
    }
  }
  
  static Future<void> exportExcel(List<Map<String, dynamic>> data) async {
    //  نفّذ تصدير Excel هنا
    debugPrint("Exporting Excel with ${data.length} records...");
  }
  
}
