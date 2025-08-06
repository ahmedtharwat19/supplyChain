import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/companies/company_added_page.dart';
import 'package:puresip_purchasing/pages/items/add_item_page.dart';
import 'package:puresip_purchasing/pages/items/edit_item_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/add_factory_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/factories_page.dart';
import 'package:puresip_purchasing/pages/purchasing/edit_puchase_order_page.dart';
import 'package:puresip_purchasing/services/order_service.dart';

// الصفحات
import 'pages/dashboard/splash_screen.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/companies/companies_page.dart';
import 'pages/companies/add_company_page.dart';
import 'pages/companies/edit_company_page.dart';
import 'pages/suppliers/suppliers_page.dart';
import 'pages/suppliers/add_supplier_page.dart';
import 'pages/suppliers/edit_supplier_page.dart';
import 'pages/purchasing/purchase_orders_page.dart';
import 'pages/purchasing/purchase_order_details_page.dart';
import 'pages/purchasing/add_purchase_order_page.dart';
import 'pages/items/items_page.dart';

// مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/companies',
      builder: (context, state) => const CompaniesPage(),
    ),
    GoRoute(
      path: '/add-company',
      builder: (context, state) => const AddCompanyPage(),
    ),
    GoRoute(
      path: '/edit-company/:id',
      builder: (context, state) {
        final companyId = state.pathParameters['id']!;
        return EditCompanyPage(companyId: companyId);
      },
    ),
    GoRoute(
      path: '/company-added/:id',
      builder: (context, state) {
        final docId = state.pathParameters['id']!;
        final nameEn = state.uri.queryParameters['nameEn'] ?? '';
        return CompanyAddedPage(nameEn: nameEn, docId: docId);
      },
    ),
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => const SuppliersPage(),
    ),
    GoRoute(
      path: '/add-supplier',
      builder: (context, state) => const AddSupplierPage(),
    ),
    GoRoute(
      path: '/edit-vendor/:id',
      builder: (context, state) {
        final supplierId = state.pathParameters['id']!;
        return EditSupplierPage(supplierId: supplierId);
      },
    ),
    GoRoute(
      path: '/purchase-orders',
      builder: (context, state) => const PurchaseOrdersPage(),
    ),
GoRoute(
      path: '/purchase/:id',
      name: 'purchase',
      builder: (context, state) {
        // الحالة 1: إذا تم تمرير PurchaseOrder كـ extra
        if (state.extra != null && state.extra is PurchaseOrder) {
          final order = state.extra as PurchaseOrder;
          return order.status == 'pending'
              ? EditPurchaseOrderPage(order: order)
              : PurchaseOrderDetailsPage(order: order);
        }
        // الحالة 2: إذا لم يتم تمرير order، جلبها من Firestore باستخدام ID
        else {
          final id = state.pathParameters['id']!;
          return FutureBuilder<PurchaseOrder>(
            future: OrderService.getOrderById(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Order not found'));
              }
              final order = snapshot.data!;
              return order.status == 'pending'
                  ? EditPurchaseOrderPage(order: order)
                  : PurchaseOrderDetailsPage(order: order);
            },
          );
        }
      },
    ),
/*     GoRoute(
      path: '/purchase-order-detail',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'] ?? '';
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return PurchaseOrderDetailPage(
          companyId: companyId,
          orderId: orderId,
        );
      },
    ), */
    GoRoute(
      path: '/add-purchase-order',
      builder: (context, state) {
        final selectedCompany =
            state.uri.queryParameters['selectedCompany'] ?? '';
        return AddPurchaseOrderPage(selectedCompany: selectedCompany);
      },
    ),
    GoRoute(
      path: '/items',
      builder: (context, state) => const ItemsPage(),
    ),
    GoRoute(
      path: '/items/add',
      builder: (context, state) => const AddItemPage(),
    ),
    GoRoute(
      path: '/edit-item/:id',
      builder: (context, state) {
        final itemId = state.pathParameters['id']!;
        return EditItemPage(itemId: itemId);
      },
    ),
    GoRoute(
        path: '/factories', builder: (context, state) => const FactoriesPage()),
    GoRoute(
        path: '/add-factory',
        builder: (context, state) => const AddFactoryPage()),
    GoRoute(
      path: '/edit-factory/:id',
      builder: (context, state) {
        final factoryId = state.pathParameters['id']!;
        return EditFactoryPage(factoryId: factoryId);
      },
    ),
  ],

  /// ✅ التوجيه حسب حالة تسجيل الدخول
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isSplash = state.fullPath == '/splash';
    final isLoggingIn =
        state.fullPath == '/login' || state.fullPath == '/signup';

    if (isSplash) return null;
    if (user == null && !isLoggingIn) return '/login';
    if (user != null && isLoggingIn) return '/dashboard';

    return null;
  },
);
