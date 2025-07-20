import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final String companyName;
  final String vendorName;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const PurchaseOrderCard({
    super.key,
    required this.data,
    required this.orderId,
    required this.companyName,
    required this.vendorName,
    required this.onDelete,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isConfirmed = data['isConfirmed'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('${'orderNo'.tr()} #$orderId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'company'.tr()}: $companyName'),
            Text('${'supplier'.tr()}: $vendorName'),
            Text('${'total'.tr()}: ${data['totalAmount']?.toStringAsFixed(2) ?? 'N/A'} ${'currency'.tr()}'),
            if (createdAt != null)
              Text('${'date'.tr()}: ${createdAt.toLocal().toString().split(' ').first}'),
            Text('${'status'.tr()}: ${isConfirmed ? 'confirmed'.tr() : 'unconfirmed'.tr()}'),
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'exportPDF'.tr(),
              onPressed: onExport,
            ),
            if (!isConfirmed) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'edit'.tr(),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'delete'.tr(),
                onPressed: onDelete,
              ),
            ]
          ],
        ),
        onTap: () {
          context.push(
              '/purchase-order-detail?companyId=${data['companyId']}&orderId=$orderId');
        },
      ),
    );
  }
}
