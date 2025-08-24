import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:puresip_purchasing/pages/inventory/services/inventory_service.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductCompositionScreen extends StatelessWidget {
  final ManufacturingOrder order;

  const ProductCompositionScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final manufacturingService = Provider.of<ManufacturingService>(context);
    final inventoryService = Provider.of<InventoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('manufacturing.composition'.tr(args: [order.productName])),
        actions: [
          if (order.status == ManufacturingStatus.pending)
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              onPressed: () => _startManufacturing(
                  context, manufacturingService, inventoryService),
              tooltip: 'manufacturing.start_manufacturing'.tr(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfoCard(),
            const SizedBox(height: 20),

            Text(
              'manufacturing.required_materials'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _buildMaterialsList(context, inventoryService),
            ),

            if (order.status == ManufacturingStatus.pending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startManufacturing(
                      context, manufacturingService, inventoryService),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                    'manufacturing.start_manufacturing'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'manufacturing.batch_number'.tr()}: ${order.batchNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${'manufacturing.product_name'.tr()}: ${order.productName}'),
            const SizedBox(height: 8),
            Text('${'manufacturing.quantity'.tr()}: ${order.quantity} ${order.productUnit}'),
            const SizedBox(height: 8),
            Text(
                '${'manufacturing.manufacturing_date'.tr()}: ${_formatDate(order.manufacturingDate)}'),
            const SizedBox(height: 8),
            Text(
                '${'manufacturing.expiry_date'.tr()}: ${_formatDate(order.expiryDate)}'),
            const SizedBox(height: 8),
            Text('${'manufacturing.status'.tr()}: ${order.statusText}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsList(
      BuildContext context, InventoryService inventoryService) {
    return StreamBuilder<Map<String, double>>(
      stream: inventoryService.getCurrentStockLevels(
          order.rawMaterials.map((rm) => rm.materialId).toList()),
      builder: (context, snapshot) {
        final stockLevels = snapshot.data ?? {};

        return ListView.builder(
          itemCount: order.rawMaterials.length,
          itemBuilder: (context, index) {
            final material = order.rawMaterials[index];
            final currentStock = stockLevels[material.materialId] ?? 0;
            final requiredQuantity = material.quantityRequired * order.quantity;
            final hasSufficientStock = currentStock >= requiredQuantity;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: hasSufficientStock ? null : Colors.red.shade100,
              child: ListTile(
                title: Text(material.materialName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${'manufacturing.required'.tr()}: $requiredQuantity ${material.unit}'),
                    Text(
                        '${'current_stock'.tr()}: $currentStock ${material.unit}'),
                    if (!hasSufficientStock)
                      Text(
                        'insufficient_stock'.tr(),
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                trailing: Text(
                  hasSufficientStock ? '✓' : '✗',
                  style: TextStyle(
                    color: hasSufficientStock ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startManufacturing(
      BuildContext context,
      ManufacturingService manufacturingService,
      InventoryService inventoryService) async {
    try {
      final hasSufficientStock = await inventoryService.checkSufficientStock(
          order.rawMaterials, order.quantity);

      if (!hasSufficientStock) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('insufficient_stock_error'.tr())));
        return;
      }

      await manufacturingService.deductRawMaterials(
          order.rawMaterials, order.quantity, order.batchNumber);

      await manufacturingService.updateOrderStatus(
          order.id, ManufacturingStatus.inProgress);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.manufacturing_started'.tr())));

      Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${'error'.tr()}: $e')));
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}