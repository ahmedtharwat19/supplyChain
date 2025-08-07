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
}