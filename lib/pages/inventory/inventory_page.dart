import 'package:flutter/material.dart';

class StockMovementsPage extends StatelessWidget {
  final String inventoryId;

  const StockMovementsPage({super.key, required this.inventoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Movements')),
      body: Center(child: Text('Displaying movements for inventory: $inventoryId')),
    );
  }
}
