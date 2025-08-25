// product_composition_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:puresip_purchasing/pages/finished_products/add_composition_screen.dart';
import 'package:puresip_purchasing/pages/finished_products/services/composition_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductCompositionScreen extends StatelessWidget {
  final String productId;
//  final String productName;
  final bool _isArabic = false;

  const ProductCompositionScreen({
    super.key,
    required this.productId,
   // required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final compositionService = Provider.of<CompositionService>(context);
    final companyService = Provider.of<CompanyService>(context);
    final factoryService = Provider.of<FactoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('manufacturing.product_composition'.tr()),
      ),
      body: StreamBuilder<ProductComposition?>(
        stream: compositionService.getCompositionByProductId(productId),
        builder: (context, snapshot) {
          // معالجة الأخطاء
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('manufacturing.error_loading_composition'.tr()),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          // حالة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final composition = snapshot.data;

          // لا يوجد تركيب
          if (composition == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('manufacturing.no_composition_found'.tr()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                   onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddCompositionScreen(productId: productId,),
                  ),);},
                    child: Text('manufacturing.add_composition'.tr()),
                  ),
                ],
              ),
            );
          }

          // عرض بيانات التركيب
          return _buildCompositionDetails(context, composition, companyService, factoryService);
        },
      ),
    );
  }

  Widget _buildCompositionDetails(
    BuildContext context,
    ProductComposition composition,
    CompanyService companyService,
    FactoryService factoryService,
  ) {
    return FutureBuilder<Company?>(
      future: companyService.getCompanyById(composition.companyId),
      builder: (context, companySnapshot) {
        return FutureBuilder<Factory?>(
          future: factoryService.getFactoryById(composition.factoryId),
          builder: (context, factorySnapshot) {
            final companyName = companySnapshot.hasData ? _isArabic ? companySnapshot.data!.nameAr : companySnapshot.data!.nameEn : '...';
            final factoryName = factorySnapshot.hasData ? _isArabic ? factorySnapshot.data!.nameAr : factorySnapshot.data!.nameEn : '...';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات أساسية
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text(
                          //   '${'product_name'.tr()}: $productName',
                          //   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          // ),
                          const SizedBox(height: 8),
                          Text('${'company'.tr()}: $companyName'),
                          Text('${'factory'.tr()}: $factoryName'),
                          Text('${'batch_size'.tr()}: ${composition.batchSize} ${composition.unit}'),
                          Text('${'shelf_life'.tr()}: ${composition.shelfLife} ${'months'.tr()}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // مواد خام
                  Text(
                    'raw_materials'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...composition.rawMaterials.map((material) => _buildMaterialCard(material)),

                  const SizedBox(height: 20),

                  // مواد تعبئة وتغليف
                  Text(
                    'packaging_materials'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...composition.packagingMaterials.map((material) => _buildMaterialCard(material)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialCard(CompositionItem material) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(material.itemId),
        subtitle: Text('${material.quantity} ${material.unit}'),
        trailing: Text(
          material.unit,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}