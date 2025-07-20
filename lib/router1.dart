import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/pages/manufacturing/add_factory_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/edit_factory_page.dart';
import 'package:puresip_purchasing/pages/manufacturing/factories_page.dart';

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
import 'pages/purchasing/purchase_order_detail_page.dart';
import 'pages/purchasing/add_purchase_order_page.dart';
import 'pages/items/items_page.dart';
import 'widgets/app_scaffold.dart';

// مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: true, // يساعدك أثناء التطوير
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
      builder: (context, state) => AppScaffold(
        title: tr('dashboard'),
        body: const DashboardPage(),
      ),
    ),
    GoRoute(
      path: '/companies',
      builder: (context, state) => AppScaffold(
        title: tr('companies'),
        body: const CompaniesPage(),
      ),
    ),
    GoRoute(
      path: '/add-company',
      builder: (context, state) => AppScaffold(
        title: tr('add_company'),
        body: const AddCompanyPage(),
      ),
    ),
    GoRoute(
      path: '/edit-company/:id',
      builder: (context, state) {
        final companyId = state.pathParameters['id']!;
        return AppScaffold(
          title: tr('edit_company'),
          body: EditCompanyPage(companyId: companyId),
        );
      },
    ),
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => AppScaffold(
        title: tr('suppliers'),
        body: const SuppliersPage(),
      ),
    ),
    GoRoute(
      path: '/add-supplier',
      builder: (context, state) => AppScaffold(
        title: tr('add_supplier'),
        body: const AddSupplierPage(),
      ),
    ),
    GoRoute(
      path: '/edit-vendor/:id',
      builder: (context, state) {
        final supplierId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AppScaffold(
          title: tr('edit_supplier'),
          body: EditSupplierPage(
            supplierId: supplierId,
            initialName: extra['name'] ?? '',
            initialCompany: extra['company'] ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/purchase-orders',
      builder: (context, state) => AppScaffold(
        title: tr('purchase_orders'),
        body: const PurchaseOrdersPage(),
      ),
    ),
    GoRoute(
      path: '/purchase-order-detail',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'] ?? '';
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return AppScaffold(
          title: tr('purchase_order_details'),
          body: PurchaseOrderDetailPage(
            companyId: companyId,
            orderId: orderId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/add-purchase-order',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'];
        final editOrderId = state.uri.queryParameters['editOrderId'];
        if (companyId == null || companyId.isEmpty) {
          return const Scaffold(body: Center(child: Text('Missing companyId')));
        }
        return AppScaffold(
          title: tr('add_purchase_order'),
          body: AddPurchaseOrderPage(
            selectedCompany: companyId,
            editOrderId: editOrderId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/items',
      builder: (context, state) => AppScaffold(
        title: tr('items'),
        body: const ItemsPage(),
      ),
    ),
    GoRoute(
      path: '/factories',
      builder: (context, state) => AppScaffold(
        title: tr('factories'),
        body: const FactoriesPage(),
      ),
    ),
    GoRoute(
      path: '/add-factory',
      builder: (context, state) => AppScaffold(
        title: tr('add_factory'),
        body: const AddFactoryPage(),
      ),
    ),
    GoRoute(
      path: '/edit-factory/:id',
      builder: (context, state) {
        final factoryId = state.pathParameters['id']!;
        return AppScaffold(
          title: tr('edit_factory'),
          body: EditFactoryPage(factoryId: factoryId),
        );
      },
    ),
    GoRoute(path:'/finished-products', builder: (context, state) {
      return AppScaffold(
        title: tr('finished_products'),
        body: const Center(child: Text('Finished Products Page')),
      );
    }),
  ],

  /// ✅ إعادة التوجيه بناءً على حالة تسجيل الدخول
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
