import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

// صفحات المشروع
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
import 'pages/items_page.dart';

// ✅ مكون app scaffold الموحد
Widget appScaffold({required String titleKey, required Widget child}) {
  return Scaffold(
    appBar: AppBar(
      title: Text(titleKey.tr()),
      actions: [
        PopupMenuButton<Locale>(
          icon: const Icon(Icons.language),
          onSelected: (locale) => EasyLocalization.of(navigatorKey.currentContext!)?.setLocale(locale),
          itemBuilder: (context) => const [
            PopupMenuItem(value: Locale('en'), child: Text('English')),
            PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
          ],
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: child,
  );
}

// ✅ مفتاح التنقل العام
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.fullPath == '/login' || state.fullPath == '/signup';

    if (state.fullPath == '/splash') return null;
    if (user == null && !isLoggingIn) return '/login';
    if (user != null && isLoggingIn) return '/';

    return null;
  },
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
      path: '/',
      builder: (context, state) => appScaffold(
        titleKey: 'dashboard',
        child: const DashboardPage(),
      ),
    ),
    GoRoute(
      path: '/companies',
      builder: (context, state) => appScaffold(
        titleKey: 'companies',
        child: const CompaniesPage(),
      ),
    ),
    GoRoute(
      path: '/add-company',
      builder: (context, state) => appScaffold(
        titleKey: 'add_company',
        child: const AddCompanyPage(),
      ),
    ),
    GoRoute(
      path: '/edit-company/:id',
      builder: (context, state) {
        final companyId = state.pathParameters['id']!;
        return appScaffold(
          titleKey: 'edit_company',
          child: EditCompanyPage(companyId: companyId),
        );
      },
    ),
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => appScaffold(
        titleKey: 'suppliers',
        child: const SuppliersPage(),
      ),
    ),
    GoRoute(
      path: '/add-supplier',
      builder: (context, state) => appScaffold(
        titleKey: 'add_supplier',
        child: const AddSupplierPage(),
      ),
    ),
    GoRoute(
      path: '/edit-vendor/:id',
      builder: (context, state) {
        final vendorId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return appScaffold(
          titleKey: 'edit_supplier',
          child: EditSupplierPage(
            vendorId: vendorId,
            initialName: extra['name'] ?? '',
            initialCompany: extra['company'] ?? '',
          ),
        );
      },
    ),
    GoRoute(
      path: '/purchase-orders',
      builder: (context, state) => appScaffold(
        titleKey: 'purchase_orders',
        child: const PurchaseOrdersPage(),
      ),
    ),
    GoRoute(
      path: '/purchase-order-detail',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'] ?? '';
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return appScaffold(
          titleKey: 'purchase_order_details',
          child: PurchaseOrderDetailPage(
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
        return appScaffold(
          titleKey: 'add_purchase_order',
          child: AddPurchaseOrderPage(
            selectedCompany: companyId,
            editOrderId: editOrderId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/items',
      builder: (context, state) => appScaffold(
        titleKey: 'items',
        child: const ItemsPage(),
      ),
    ),
  ],
);
