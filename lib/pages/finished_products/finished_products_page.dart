import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/pages/finished_products/add_finished_product_screen.dart';
import 'package:puresip_purchasing/pages/finished_products/product_composition_screen.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

import '../../models/company.dart';
import '../../models/factory.dart';
import '../../services/company_service.dart';
import '../../services/factory_service.dart';

class FinishedProductsPage extends StatefulWidget {
  const FinishedProductsPage({super.key});

  @override
  State<FinishedProductsPage> createState() => _FinishedProductsPageState();
}

class _FinishedProductsPageState extends State<FinishedProductsPage> {
//  String _filterStatus = 'all'; // all, expired, expiring_soon, good
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  final TextEditingController _searchController = TextEditingController();
   bool get _isArabic => context.locale.languageCode == 'ar';
    final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manufacturingService = Provider.of<ManufacturingService>(context);
    final companyService = Provider.of<CompanyService>(context);
    final factoryService = Provider.of<FactoryService>(context);

    return AppScaffold(
      title: 'manufacturing.finished_products'.tr(),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddFinishedProductScreen(),
              ),
            );
          },
          tooltip: 'manufacturing.add_finished_product'.tr(),
        ),
      ],
      body: Column(
        children: [
          // شريط البحث والتصفية
          _buildFilterBar(context, companyService, factoryService),
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
                    return _buildProductCard(context, product, companyService, factoryService);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, CompanyService companyService, FactoryService factoryService) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'search'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          
          // فلتر الشركة (إذا كان للمستخدم أكثر من شركة)
          StreamBuilder<List<Company>>(
            stream: companyService.getUserCompanies(_currentUser!.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.length > 1) {
                final companies = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCompanyId,
                  decoration: InputDecoration(
                    labelText: 'company'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('all_companies'.tr()),
                    ),
                    ...companies.map((company) {
                      return DropdownMenuItem(
                        value: company.id,
                        child: Text(_isArabic ? company.nameAr : company.nameEn),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCompanyId = value;
                      _selectedFactoryId = null; // إعادة تعيين المصنع عند تغيير الشركة
                    });
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 8),
          
          // فلتر المصنع (إذا تم اختيار شركة)
          if (_selectedCompanyId != null)
            StreamBuilder<List<Factory>>(
              stream: factoryService.getFactoriesByCompany(_selectedCompanyId!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final factories = snapshot.data!;
                  if (factories.isNotEmpty) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedFactoryId,
                      decoration: InputDecoration(
                        labelText: 'factory'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('all_factories'.tr()),
                        ),
                        ...factories.map((factory) {
                          return DropdownMenuItem(
                            value: factory.id,
                            child: Text(_isArabic ? factory.nameAr : factory.nameEn),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedFactoryId = value;
                        });
                      },
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          
          const SizedBox(height: 8),
          
          // فلتر حالة الصلاحية
    /*       Row(
            children: [
              Text('filter'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterStatus,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('all'.tr())),
                    DropdownMenuItem(value: 'expired', child: Text('manufacturing.expired'.tr())),
                    DropdownMenuItem(value: 'expiring_soon', child: Text('manufacturing.expiring_soon'.tr())),
                    DropdownMenuItem(value: 'good', child: Text('manufacturing.good'.tr())),
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
     */
        ],
      ),
    );
  }

  List<FinishedProduct> _filterProducts(List<FinishedProduct> products) {
    // التصفية حسب البحث
    List<FinishedProduct> filtered = products;
    
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
               product.batchNumber.toLowerCase().contains(_searchController.text.toLowerCase());
      }).toList();
    }
    
    // التصفية حسب الشركة
    if (_selectedCompanyId != null) {
      filtered = filtered.where((product) => product.companyId == _selectedCompanyId).toList();
    }
    
    // التصفية حسب المصنع
    if (_selectedFactoryId != null) {
      filtered = filtered.where((product) => product.factoryId == _selectedFactoryId).toList();
    }
    
/*     // التصفية حسب حالة الصلاحية
    switch (_filterStatus) {
      case 'expired':
        return filtered.where((p) => p.isExpired).toList();
      case 'expiring_soon':
        return filtered.where((p) => p.isExpiringSoon && !p.isExpired).toList();
      case 'good':
        return filtered.where((p) => !p.isExpired && !p.isExpiringSoon).toList();
      default:
        return filtered;
    }
   */
    return filtered;
  }

  Widget _buildProductCard(BuildContext context, FinishedProduct product, CompanyService companyService, FactoryService factoryService) {
    return FutureBuilder<Company?>(
      future: companyService.getCompanyById(product.companyId),
      builder: (context, companySnapshot) {
        return FutureBuilder<Factory?>(
          future: factoryService.getFactoryById(product.factoryId),
          builder: (context, factorySnapshot) {
            final companyName = companySnapshot.hasData ? _isArabic ? companySnapshot.data!.nameAr : companySnapshot.data!.nameEn : 'Loading...';
            final factoryName = factorySnapshot.hasData ? _isArabic ? factorySnapshot.data!.nameAr : factorySnapshot.data!.nameEn : 'Loading...';
            
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
                    // عرض اسم الشركة والمصنع
                    if (companyName.isNotEmpty)
                      Text('${'company'.tr()}: $companyName'),
                    if (factoryName.isNotEmpty)
                      Text('${'factory'.tr()}: $factoryName'),
                    Text('${'manufacturing.batch_number'.tr()}: ${product.batchNumber}'),
                    Text('${'manufacturing.quantity'.tr()}: ${product.quantity} ${product.unit}'),
                    Text('${'manufacturing.production_date'.tr()}: ${_formatDate(product.dateTime)}'),
                    Text('${'manufacturing.expiry_date'.tr()}: ${_formatDate(product.expiryDateTime)}'),
                    if (product.isExpired)
                      Text(
                        'manufacturing.expired'.tr(),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      )
                    else if (product.isExpiringSoon)
                      Text(
                        'manufacturing.expiring_soon'.tr(),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    _buildDaysRemaining(product),
                  ],
                ),
                trailing: _buildStatusIcon(product),
                onTap: () => _showProductDetails(context, product, companyName, factoryName),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDaysRemaining(FinishedProduct product) {
    if (product.isExpired) {
      final daysExpired = DateTime.now().difference(product.expiryDateTime).inDays;
      return Text(
        '${'manufacturing.days_expired'.tr()}: $daysExpired',
        style: const TextStyle(color: Colors.red),
      );
    } else {
      final daysRemaining = product.expiryDateTime.difference(DateTime.now()).inDays;
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

 // في finished_products_page.dart عند الضغط على الكارت
void _showProductDetails(BuildContext context, FinishedProduct product, String companyName, String factoryName) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(product.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (companyName.isNotEmpty)
              Text('${'company'.tr()}: $companyName'),
            if (factoryName.isNotEmpty)
              Text('${'factory'.tr()}: $factoryName'),
            
            Text('${'manufacturing.batch_number'.tr()}: ${product.batchNumber}'),
            Text('${'manufacturing.quantity'.tr()}: ${product.quantity} ${product.unit}'),
            Text('${'manufacturing.production_date'.tr()}: ${_formatDateDetailed(product.dateTime)}'),
            Text('${'manufacturing.expiry_date'.tr()}: ${_formatDateDetailed(product.expiryDateTime)}'),
            Text('${'manufacturing.created_at'.tr()}: ${_formatDateDetailed(product.createdAtDateTime)}'),
            
            const SizedBox(height: 16),
            
            if (product.isExpired)
              Text(
                'manufacturing.expired'.tr(),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else if (product.isExpiringSoon)
              Text(
                'manufacturing.expiring_soon'.tr(),
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              )
            else
              Text(
                'manufacturing.good'.tr(),
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 16),
            
            // زر عرض بيان التركيب
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // إغلاق الديالوج الحالي
                  _showCompositionDetails(context, product);
                },
                child: Text('manufacturing.show_composition'.tr()),
              ),
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

void _showCompositionDetails(BuildContext context, FinishedProduct product) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProductCompositionScreen(
        productId: product.id!, // استخدام معرف المنتج
     //   productName: product.name, // تمرير اسم المنتج
      ),
    ),
  );
}




  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateDetailed(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}