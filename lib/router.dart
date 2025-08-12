import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:puresip_purchasing/widgets/auth/admin_license_management.dart';
import 'package:puresip_purchasing/widgets/auth/user_license_request.dart';

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
final _licenseService = LicenseService();

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
        if (state.extra != null && state.extra is PurchaseOrder) {
          final order = state.extra as PurchaseOrder;
          return order.status == 'pending'
              ? EditPurchaseOrderPage(order: order)
              : PurchaseOrderDetailsPage(order: order);
        } else {
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
      path: '/factories',
      builder: (context, state) => const FactoriesPage(),
    ),
    GoRoute(
      path: '/add-factory',
      builder: (context, state) => const AddFactoryPage(),
    ),
    GoRoute(
      path: '/edit-factory/:id',
      builder: (context, state) {
        final factoryId = state.pathParameters['id']!;
        return EditFactoryPage(factoryId: factoryId);
      },
    ),
    GoRoute(
      path: '/license-request',
      builder: (context, state) => const UserLicenseRequestPage(),
    ),
    GoRoute(
      path: '/admin/licenses',
      builder: (context, state) => const AdminLicenseManagementPage(),
    ),
  ],
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isSplash = state.fullPath == '/splash';
    final isAuth = ['/login', '/signup'].contains(state.fullPath);
    final isLicensePath =
        ['/license-request', '/admin/licenses'].contains(state.fullPath);

    // 1. Splash screen handling
    if (isSplash) {
      return user != null ? '/dashboard' : '/login';
    }

    // 2. Unauthenticated users
    if (user == null) {
      return isAuth ? null : '/login';
    }

    // 3. Check permissions
    try {
      final isAdmin = await _checkIfAdmin(user.uid);
      
      final licenseStatus = await _licenseService.checkLicenseStatus();

      debugPrint('''
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Days Left: ${licenseStatus.daysLeft}
      Current Path: ${state.fullPath}
    ''');

      // 3.1 Admin routing
      if (isAdmin) {
        // يسمح للإدمن بالدخول إلى صفحة الترخيص الخاصة به
        if (isLicensePath) {
          return null;
        }

        // يمنعه من الدخول لأي صفحة غير مصرح بها ويرجعه إلى لوحة التحكم
        if (state.fullPath != '/dashboard') {
          return '/dashboard';
        }

        return null;
      }

/*       if (isAdmin) {
        return isLicensePath ? null : '/admin/licenses';
      } */
/*       if (isAdmin) {
        // إذا هو ليس في dashboard بالفعل، يذهب له
        if (state.fullPath != '/dashboard') {
          return '/dashboard';
        }
        return null; // إذا في dashboard، يبقى
      } */
      // 3.2 Check license validity
      if (!licenseStatus.isValid) {
        // Only redirect to license request if not already there
        return state.fullPath == '/license-request' ? null : '/license-request';
      }

      // 3.3 If license is valid but on license page, go to dashboard
      if (isLicensePath) {
        return '/dashboard';
      }

      // 3.4 Prevent going back to auth pages
      if (isAuth) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      debugPrint('Router Error: $e');
      return '/login';
    }
  },
);

Future<bool> _checkIfAdmin(String userId) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['isAdmin'] == true;
  } catch (e) {
    return false;
  }
}


/*   redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isSplash = state.fullPath == '/splash';
    final isLoggingIn =
        state.fullPath == '/login' || state.fullPath == '/signup';
    final isLicenseRequest = state.fullPath == '/license-request';
    final isAdminLicense = state.fullPath == '/admin/licenses';

    // حالة شاشة البداية
    if (isSplash) return null;

    // حالة عدم تسجيل الدخول
    if (user == null) {
      return isLoggingIn ? null : '/login';
    }

    // التحقق من الصلاحيات الإدارية
    final isAdmin = await _checkIfAdmin(user.uid);

    // توجيه الإداريين
    if (isAdmin) {
      return isAdminLicense ? null : '/admin/licenses';
    }

    // توجيه المستخدمين العاديين
    final licenseStatus = await _licenseService.checkLicenseStatus();
    if (!licenseStatus.isValid) {
      return isLicenseRequest ? null : '/license-request';
    }

    // توجيه عام بعد التحقق
    if (isLoggingIn) {
      return licenseStatus.isValid ? '/dashboard' : '/license-request';
    }

    return null;
  },
); */

/*   redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isSplash = state.fullPath == '/splash';
    final isAuth = ['/login', '/signup'].contains(state.fullPath);
    final isLicense = ['/license-request', '/admin/licenses'].contains(state.fullPath);

    // 1. معالجة شاشة البداية
    if (isSplash) {
      return user != null ? '/dashboard' : '/login';
    }

    // 2. المستخدم غير مسجل الدخول
    if (user == null) {
      return isAuth ? null : '/login';
    }

    // 3. التحقق من الصلاحيات (بعد إصلاح checkLicenseStatus)
    try {
      final isAdmin = await _checkIfAdmin(user.uid);
      final licenseStatus = await _licenseService.checkLicenseStatus();

      debugPrint('''
        User: ${user.uid}
        Is Admin: $isAdmin
        License Valid: ${licenseStatus.isValid}
        Current Path: ${state.fullPath}
      ''');

      // 3.1 توجيه الإداريين
      if (isAdmin) {
        return state.fullPath == '/admin/licenses' ? null : '/admin/licenses';
      }

      // 3.2 توجيه المستخدمين العاديين
      if (!licenseStatus.isValid) {
        return state.fullPath == '/license-request' ? null : '/license-request';
      }

      // 3.3 منع العودة إلى صفحات التسجيل إذا كان مسجلاً
      if (isAuth) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      debugPrint('Router Error: $e');
      return '/login'; // Fallback
    }
  },
); */

  /*  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isSplash = state.fullPath == '/splash';
    final isAuth = ['/login', '/signup'].contains(state.fullPath);
    final isLicensePath =
        ['/license-request', '/admin/licenses'].contains(state.fullPath);

    // 1. Splash screen handling
    if (isSplash) {
      return user != null ? '/dashboard' : '/login';
    }

    // 2. Unauthenticated users
    if (user == null) {
      return isAuth ? null : '/login';
    }

    // 3. Check permissions
    try {
      final isAdmin = await _checkIfAdmin(user.uid);
      final licenseStatus = await _licenseService.checkLicenseStatus();

      debugPrint('''
      User: ${user.uid}
      Is Admin: $isAdmin
      License Valid: ${licenseStatus.isValid}
      Current Path: ${state.fullPath}
    ''');

      // 3.1 Admin routing
      if (isAdmin) {
        return isLicensePath ? null : '/admin/licenses';
      }

      // 3.2 Regular user with invalid license
      if (!licenseStatus.isValid) {
        return isLicensePath ? null : '/license-request';
      }

      // 3.3 Prevent going back to auth pages
      if (isAuth) {
        return '/dashboard';
      }

      return null;
    } catch (e) {
      debugPrint('Router Error: $e');
      return '/login';
    }
  },
 */
