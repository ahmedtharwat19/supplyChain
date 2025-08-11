/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() => _isLoading = true);
    _deviceId = await _licenseService.getDeviceUniqueId();
    setState(() => _isLoading = false);
  }

  Future<void> _submitRequest() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_required'.tr())),
      );

      return;
    }

    final isConnected = await _licenseService.checkInternetConnection();
  if (!isConnected && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('no_internet'.tr())),
    );
    return;
  }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('confirm_request'.tr()),
            content: Text('confirm_request_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('confirm'.tr()),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_sent'.tr())),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'request_error'.tr()}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDeviceCount = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDuration = value!);
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */
/* 

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(String message, String route) async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    
    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : (value) {
                      if (value != null) {
                        setState(() => _selectedDeviceCount = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : (value) {
                      if (value != null) {
                        setState(() => _selectedDuration = value);
                      }
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 12;
  bool _isLoading = false;

  Map<String, dynamic>? _currentLicenseRequest;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _initializeLicenseRequest();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } catch (e) {
      // Handle error if needed
      print('Error loading device ID: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeLicenseRequest() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      // جلب الطلب الحالي للمستخدم
      final existingRequest = await _licenseService.getUserLicenseRequest(user.uid);

      if (mounted) {
        setState(() {
          _currentLicenseRequest = existingRequest;
        });
      }

      // إذا الطلب موجود وحالته "approved" توجيه مباشر
      if (existingRequest != null && existingRequest['status'] == 'approved') {
        if (mounted) {
          context.go('/dashboard');
        }
      }

      // يمكن الاستماع لتغييرات الطلب في حال وجود دعم Stream (اختياري)
      _listenToLicenseStatus(user.uid);

    } catch (e) {
      print('Error initializing license request: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // استماع لتغير حالة الترخيص (اختياري، لتحويل المستخدم تلقائيًا)
  void _listenToLicenseStatus(String userId) {
    _licenseService.licenseRequestStream(userId).listen((docSnapshot) {
      final data = docSnapshot.data();
      if (data != null) {
        setState(() {
          _currentLicenseRequest = data;
        });
        if (data['status'] == 'approved' && mounted) {
          context.go('/dashboard');
        }
      }
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(String message, String route) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    // منع إرسال طلب جديد إذا يوجد طلب معلق
    if (_currentLicenseRequest != null && _currentLicenseRequest!['status'] == 'pending') {
      await _showErrorSnackBar('existing_request_pending'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      // تحديث حالة الطلب الحالي
      await _initializeLicenseRequest();

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _listenToLicenseStatus();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) {
        setState(() => _deviceId = deviceId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToLicenseStatus() {
    final user = _auth.currentUser;
    if (user == null) return;

    _licenseService.licenseRequestStream(user.uid).listen((docSnapshot) {
      if (!mounted) return;

      final data = docSnapshot.data() as Map<String, dynamic>?;
      debugPrint('License Request Data: $data'); // تحقق من البيانات

      if (data != null) {
        final status = data['status'] as String?;
        if (status == 'approved') {
          debugPrint('License approved, navigating to dashboard');

          // عند الموافقة، تحويل المستخدم للوحة التحكم
          context.go('/dashboard');
        }
      }
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSuccessSnackBarAndRedirect(
      String message, String route) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.go(route);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

/*   Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // فحص وجود طلب ترخيص معلق مسبقاً
      final hasPending = await _licenseService.hasPendingLicenseRequests();
      if (hasPending) {
        await _showErrorSnackBar('existing_request_pending'.tr());
        return;
      }

      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  } */

/* Future<void> _submitRequest() async {
  if (!mounted || _isLoading) return;

  final user = _auth.currentUser;
  if (user == null) {
    await _showErrorSnackBar('login_required'.tr());
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 1. تحقق من وجود طلب سابق "موافق عليه"
    final approvedRequestsSnapshot = await _licenseService._firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    if (approvedRequestsSnapshot.docs.isNotEmpty) {
      // الطلب موافق عليه سابقاً => توجه للـ dashboard مع رسالة نجاح
      await _showSuccessSnackBarAndRedirect('request_already_approved'.tr(), '/dashboard');
      return;
    }

    // 2. تحقق من وجود طلب "معلق" قيد الانتظار
    final pendingRequestsSnapshot = await _licenseService._firestore
        .collection('license_requests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pendingRequestsSnapshot.docs.isNotEmpty) {
      await _showErrorSnackBar('existing_request_pending'.tr());
      return;
    }

    // 3. تحقق من الاتصال بالإنترنت
    final isConnected = await _licenseService.checkInternetConnection();
    if (!isConnected) {
      await _showErrorSnackBar('no_internet'.tr());
      return;
    }

    final confirm = await _showConfirmationDialog();
    if (!confirm) return;

    // 4. إرسال طلب جديد
    await _licenseService.requestNewLicense(
      userId: user.uid,
      durationMonths: _selectedDuration,
      maxDevices: _selectedDeviceCount,
    );

    await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
  } catch (e) {
    await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
 */

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasApproved =
          await _licenseService.hasApprovedLicenseRequest(user.uid);
      if (hasApproved) {
        await _showSuccessSnackBarAndRedirect(
            'request_already_approved'.tr(), '/dashboard');
        return;
      }

      final hasPending =
          await _licenseService.hasPendingLicenseRequest(user.uid);
      if (hasPending) {
        await _showErrorSnackBar('existing_request_pending'.tr());
        return;
      }

      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );

      await _showSuccessSnackBarAndRedirect('request_sent'.tr(), '/dashboard');
    } catch (e) {
      await _showErrorSnackBar('${'request_error'.tr()}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
 */

// lib/widgets/auth/user_license_request.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLicenseRequestPage extends StatefulWidget {
  const UserLicenseRequestPage({super.key});

  @override
  State<UserLicenseRequestPage> createState() => _UserLicenseRequestPageState();
}

class _UserLicenseRequestPageState extends State<UserLicenseRequestPage> {
  final _licenseService = LicenseService();
  final _auth = FirebaseAuth.instance;

  String _deviceId = 'loading_device_id'.tr();
  int _selectedDeviceCount = 1;
  int _selectedDuration = 1;
  bool _isLoading = false;

  StreamSubscription? _requestSub;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _startListeningToRequest();
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final deviceId = await _licenseService.getDeviceUniqueId();
      if (mounted) setState(() => _deviceId = deviceId);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startListeningToRequest() {
    final user = _auth.currentUser;
    if (user == null) return;

    _requestSub =
        _licenseService.licenseRequestStream(user.uid).listen((docSnapshot) {
      if (!mounted) return;

      final data = docSnapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'approved') {
        // إظهار Snack ثم التحويل للوحة التحكم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_approved'.tr())),
        );
        // ننتظر لحظة بسيطة حتى يرى المستخدم الاشعار
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          context.go('/dashboard');
        });
      } else if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_rejected'.tr())),
        );
      }
    }, onError: (e) {
      debugPrint('licenseRequest stream error: $e');
    });
  }

  Future<void> _showErrorSnackBar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_request'.tr()),
        content: Text('confirm_request_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _submitRequest() async {
    if (!mounted || _isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      await _showErrorSnackBar('login_required'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. تحقق من وجود طلب سابق للمستخدم
      final lastRequest = await _licenseService.getUserLicenseRequest(user.uid);
      if (lastRequest != null) {
        final status = lastRequest['status'] as String? ?? '';
        if (status == 'pending') {
          await _showErrorSnackBar('existing_request_pending'.tr());
          return;
        } else if (status == 'approved') {
          // لو تمت الموافقة مسبقًا، حول للداشبورد وأخبره
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('request_already_approved'.tr())));
          // ننتظر قليلاً ثم نذهب
          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) context.go('/dashboard');
          return;
        }
        // إذا حالة سابقة كانت rejected أو غير موجودة — مسموح بالإرسال
      }

      // 2. تحقق من وجود اتصال
      final isConnected = await _licenseService.checkInternetConnection();
      if (!isConnected) {
        await _showErrorSnackBar('no_internet'.tr());
        return;
      }

      final confirm = await _showConfirmationDialog();
      if (!confirm) return;

      // 3. أرسل الطلب (الـ service سيمنع التكرار بالمرة إذا وجد طلب pending)
      await _licenseService.requestNewLicense(
        userId: user.uid,
        durationMonths: _selectedDuration,
        maxDevices: _selectedDeviceCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('request_sent'.tr())));

      // نترك المستخدم في الصفحة أو نعيده للداشبورد حسب متطلباتك:
      // هنا نعيده للوحة التحكم بعد فترة قصيرة
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final msg = e is LicenseException ? e.message : e.toString();
      await _showErrorSnackBar('${'request_error'.tr()}: $msg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('new_license_request'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('device_info'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${'device_id'.tr()}: $_deviceId'),
                  const SizedBox(height: 24),
                  Text('allowed_devices'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDeviceCount,
                    items: [1, 2, 3].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count ${'devices'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDeviceCount = value);
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  Text('subscription_duration'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: [1, 3, 6, 12, 24].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months ${'months'.tr()}'),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedDuration = value);
                            }
                          },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text('send_request'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
