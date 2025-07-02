import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// صفحات المشروع
import 'pages/splash_screen.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/companies/companies_page.dart';
import 'pages/companies/add_company_page.dart';
import 'pages/companies/edit_company_page.dart';
import 'pages/suppliers_page.dart';
import 'pages/add_supplier_page.dart';
import 'pages/edit_supplier_page.dart';
import 'pages/purchase_orders_page.dart';
import 'pages/purchase_order_detail_page.dart';
import 'pages/add_purchase_order_page.dart'; // تأكد من وجود هذا الملف
import 'pages/items_page.dart';
import 'pages/missing_parameter_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn =
        state.fullPath == '/login' || state.fullPath == '/signup';

    if (state.fullPath == '/splash') return null;
    if (user == null && !isLoggingIn) return '/login';
    if (user != null && isLoggingIn) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/',
      name: 'dashboard',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const DashboardPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/companies',
      name: 'companies',
      builder: (context, state) => const CompaniesPage(),
    ),
    GoRoute(
      path: '/add-company',
      name: 'add-company',
      builder: (context, state) => const AddCompanyPage(),
    ),
    GoRoute(
      path: '/edit-company/:id',
      name: 'edit-company',
      builder: (context, state) {
        final companyId = state.pathParameters['id']!;
        return EditCompanyPage(companyId: companyId);
      },
    ),
    GoRoute(
      path: '/suppliers',
      name: 'suppliers',
      builder: (context, state) => const SuppliersPage(),
    ),
    GoRoute(
      path: '/add-supplier',
      name: 'add-supplier',
      builder: (context, state) => const AddSupplierPage(),
    ),
    GoRoute(
      path: '/edit-vendor/:id',
      name: 'edit-vendor',
      builder: (context, state) {
        final vendorId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return EditSupplierPage(
          vendorId: vendorId,
          initialName: extra['name'] ?? '',
          initialCompany: extra['company'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/purchase-orders',
      name: 'purchase-orders',
      builder: (context, state) => const PurchaseOrdersPage(),
    ),
    GoRoute(
      path: '/purchase-order-detail',
      name: 'purchase-order-detail',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'] ?? '';
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return PurchaseOrderDetailPage(
          companyId: companyId,
          orderId: orderId,
        );
      },
    ),
    GoRoute(
      path: '/add-purchase-order',
      name: 'add-purchase-order',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'];
        if (companyId == null || companyId.isEmpty) {
          return const MissingParameterPage(parameterName: 'companyId');
        }
        return AddPurchaseOrderPage(selectedCompany: companyId);
      },
    ),
    GoRoute(
      path: '/items',
      name: 'items',
      builder: (context, state) => const ItemsPage(),
    ),
  ],
);
