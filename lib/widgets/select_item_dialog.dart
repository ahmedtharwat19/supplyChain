import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectItemDialog extends StatelessWidget {
  final String companyId;

  const SelectItemDialog({super.key, required this.companyId});

  String _getItemTypeDisplayName(String type) {
    switch (type) {
      case 'raw_material':
        return 'خامة';
      case 'packaging_material':
        return 'مواد تعبئة وتغليف';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار صنف'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companies/$companyId/items')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد أصناف متاحة لهذه الشركة.'));
            }

            final items = snapshot.data!.docs;
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final data = item.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                    'السعر: ${data['unitPrice']?.toStringAsFixed(2) ?? 'N/A'} ج.م - '
                    'النوع: ${_getItemTypeDisplayName(data['type'] ?? 'N/A')}',
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'id': item.id,
                      'name': data['name'],
                      'unitPrice': data['unitPrice'],
                      'type': data['type'],
                    });
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}