import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/pages/manufacturing/add_manufacturing_order_screen.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class FinishedProductsPage extends StatefulWidget {
  const FinishedProductsPage({super.key});

  @override
  State<FinishedProductsPage> createState() => _FinishedProductsPageState();
}

class _FinishedProductsPageState extends State<FinishedProductsPage> {
  String _filterStatus = 'all'; // all, expired, expiring_soon, good

  @override
  Widget build(BuildContext context) {
    final manufacturingService = Provider.of<ManufacturingService>(context);

    return AppScaffold(
      title: 'manufacturing.finished_products'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.inventory),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FinishedProductsPage(),
              ),
            );
          },
          tooltip: 'manufacturing.finished_products'.tr(),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddManufacturingOrderScreen(),
              ),
            );
          },
          tooltip: 'manufacturing.add_order'.tr(),
        ),
      ],
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<FinishedProduct>>(
              stream: manufacturingService.getFinishedProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('error_loading_data'.tr()));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data ?? [];
                final filteredProducts = _filterProducts(products);

                if (filteredProducts.isEmpty) {
                  return Center(child: Text('no_finished_products'.tr()));
                }

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Text('filter'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterStatus,
              items: [
                DropdownMenuItem(value: 'all', child: Text('all'.tr())),
                DropdownMenuItem(
                    value: 'expired',
                    child: Text('manufacturing.expired'.tr())),
                DropdownMenuItem(
                    value: 'expiring_soon',
                    child: Text('manufacturing.expiring_soon'.tr())),
                DropdownMenuItem(
                    value: 'good', child: Text('manufacturing.good'.tr())),
              ],
              onChanged: (value) {
                setState(() {
                  _filterStatus = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  List<FinishedProduct> _filterProducts(List<FinishedProduct> products) {
    switch (_filterStatus) {
      case 'expired':
        return products.where((p) => p.isExpired).toList();
      case 'expiring_soon':
        return products.where((p) => p.isExpiringSoon && !p.isExpired).toList();
      case 'good':
        return products
            .where((p) => !p.isExpired && !p.isExpiringSoon)
            .toList();
      default:
        return products;
    }
  }

  Widget _buildProductCard(FinishedProduct product) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: product.isExpired ? Colors.red : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${'manufacturing.batch_number'.tr()}: ${product.batchNumber}'),
            Text(
                '${'manufacturing.quantity'.tr()}: ${product.quantity} ${product.unit}'),
            Text(
                '${'manufacturing.production_date'.tr()}: ${_formatDate(product.dateTime)}'),
            Text(
                '${'manufacturing.expiry_date'.tr()}: ${_formatDate(product.expiryDateTime)}'),
            if (product.isExpired)
              Text(
                'manufacturing.expired'.tr(),
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              )
            else if (product.isExpiringSoon)
              Text(
                'manufacturing.expiring_soon'.tr(),
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            _buildDaysRemaining(product),
          ],
        ),
        trailing: _buildStatusIcon(product),
        onTap: () => _showProductDetails(product),
      ),
    );
  }

  Widget _buildDaysRemaining(FinishedProduct product) {
    if (product.isExpired) {
      final daysExpired =
          DateTime.now().difference(product.expiryDateTime).inDays;
      return Text(
        '${'manufacturing.days_expired'.tr()}: $daysExpired',
        style: const TextStyle(color: Colors.red),
      );
    } else {
      final daysRemaining =
          product.expiryDateTime.difference(DateTime.now()).inDays;
      return Text(
        '${'manufacturing.days_remaining'.tr()}: $daysRemaining',
        style: TextStyle(
          color: product.isExpiringSoon ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Widget _buildStatusIcon(FinishedProduct product) {
    if (product.isExpired) {
      return const Icon(Icons.warning, color: Colors.red, size: 30);
    } else if (product.isExpiringSoon) {
      return const Icon(Icons.warning, color: Colors.orange, size: 30);
    } else {
      return const Icon(Icons.check_circle, color: Colors.green, size: 30);
    }
  }

  void _showProductDetails(FinishedProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${'manufacturing.batch_number'.tr()}: ${product.batchNumber}'),
              Text(
                  '${'manufacturing.quantity'.tr()}: ${product.quantity} ${product.unit}'),
              Text(
                  '${'manufacturing.production_date'.tr()}: ${_formatDateDetailed(product.dateTime)}'),
              Text(
                  '${'manufacturing.expiry_date'.tr()}: ${_formatDateDetailed(product.expiryDateTime)}'),
              Text(
                  '${'manufacturing.created_at'.tr()}: ${_formatDateDetailed(product.createdAtDateTime)}'),
              const SizedBox(height: 16),
              if (product.isExpired)
                Text(
                  'manufacturing.expired'.tr(),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                )
              else if (product.isExpiringSoon)
                Text(
                  'manufacturing.expiring_soon'.tr(),
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                )
              else
                Text(
                  'manufacturing.good'.tr(),
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateDetailed(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm').format(date);
  }
}
