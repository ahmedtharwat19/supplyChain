import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';

class ProductCompositionScreen extends StatelessWidget {
  final ManufacturingOrder order;

  const ProductCompositionScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('بيان تركيب ${order.productName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            const Text(
              'المواد الخام المطلوبة:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: order.rawMaterials.length,
                itemBuilder: (context, index) {
                  final material = order.rawMaterials[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(material.materialName),
                      subtitle: Text('الكمية: ${material.quantityRequired} ${material.unit}'),
                      trailing: Text('لكل ${order.quantity} وحدة'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم التشغيلة: ${order.batchNumber}', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('الكمية: ${order.quantity} وحدة'),
            const SizedBox(height: 8),
            Text('تاريخ التصنيع: ${_formatDate(order.manufacturingDate)}'),
            const SizedBox(height: 8),
            Text('تاريخ الانتهاء: ${_formatDate(order.expiryDate)}'),
            const SizedBox(height: 8),
            Text('الحالة: ${_getStatusText(order.status)}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _getStatusText(ManufacturingStatus status) {
    switch (status) {
      case ManufacturingStatus.pending: return 'قيد الانتظار';
      case ManufacturingStatus.inProgress: return 'قيد التصنيع';
      case ManufacturingStatus.completed: return 'مكتمل';
      case ManufacturingStatus.cancelled: return 'ملغى';
    }
  }
}