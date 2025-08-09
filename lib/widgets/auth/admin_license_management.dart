import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  late final LicenseService _licenseService;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
      });

      if (_isAdmin) {
        await _licenseService.initializeForAdmin();
      }
    } catch (e) {
      setState(() => _errorMessage = 'admin_check_failed'.tr());
    }
  }

/*   Future<void> _processRequest(String requestId, bool approve) async {
    if (!mounted || !_isAdmin) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final requestDoc =
          await _firestore.collection('license_requests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Request document not found');
      }

      final requestData = requestDoc.data()!;

      if (approve) {
        await _licenseService.generateLicenseKey(
          userId: requestData['userId'],
          durationMonths: requestData['durationMonths'],
          maxDevices: requestData['requestedDevices'],
        );
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _licenseService.currentUserId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                approve ? 'request_approved'.tr() : 'request_rejected'.tr()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'processing_error'.tr());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        debugPrint('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  } */

 Future<void> _processRequest(String requestId, bool approve) async {
  if (!mounted || !_isAdmin) return;

  setState(() {
    _isProcessing = true;
    _errorMessage = null;
  });

  try {
    final requestDoc = await _firestore.collection('license_requests').doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Request document not found');

    final requestData = requestDoc.data()!;

    if (approve) {
      // إنشاء الترخيص وتفعيل المستخدم
      await _licenseService.generateLicenseKey(
        userId: requestData['userId'],
        durationMonths: requestData['durationMonths'],
        maxDevices: requestData['requestedDevices'],
      );
final int durationMonths = (requestData['durationMonths'] ?? 1).toInt();
      // تفعيل حساب المستخدم
      await _firestore.collection('users').doc(requestData['userId']).update({
        'is_active': true,
      'license_expiry': DateTime.now().add(Duration(days: 30 * durationMonths)),
      });
    }

    await _firestore.collection('license_requests').doc(requestId).update({
      'status': approve ? 'approved' : 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
      'processedBy': _licenseService.currentUserId,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'request_approved'.tr() : 'request_rejected'.tr())),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _errorMessage = 'processing_error'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  Widget _buildIndexErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Index Required',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This query requires a Firestore index to be created.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://console.firebase.google.com');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not launch browser'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Create Index'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_management'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _isAdmin
          ? _buildMainContent(context)
          : _buildAdminRestricted(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    debugPrint(_errorMessage);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'pending_requests'.tr()),
              Tab(text: 'licenses'.tr()),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRequestsList(context),
                _buildLicensesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminRestricted(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64),
          const SizedBox(height: 16),
          Text(
            'admin_access_required'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'only_admins_can_access'.tr(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
            return _buildIndexErrorWidget(context);
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(child: Text('no_requests'.tr()));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestItem(request);
          },
        );
      },
    );
  }

  Widget _buildRequestItem(QueryDocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${data['userId']}'),
            Text('Devices: ${data['requestedDevices']}'),
            Text('Duration: ${data['durationMonths']} months'),
            Text('Date: ${_formatDate(data['createdAt']?.toDate())}'),
            const SizedBox(height: 16),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _processRequest(request.id, false),
                    child: Text('reject'.tr()),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _processRequest(request.id, true),
                    child: Text('approve'.tr()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicensesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data?.docs ?? [];

        if (licenses.isEmpty) {
          return Center(child: Text('no_licenses'.tr()));
        }

        return ListView.builder(
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index];
            return _buildLicenseItem(license);
          },
        );
      },
    );
  }

  Widget _buildLicenseItem(QueryDocumentSnapshot license) {
    final data = license.data() as Map<String, dynamic>;
    final expiryDate = data['expirationDate']?.toDate();
    final isExpired = expiryDate != null && DateTime.now().isAfter(expiryDate);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('License Key: ${data['licenseKey']}'),
            Text('User: ${data['userId']}'),
            Text(
                'Devices: ${(data['deviceIds'] as List?)?.length ?? 0}/${data['maxDevices']}'),
            Text('Expires: ${_formatDate(expiryDate)}'),
            Row(
              children: [
                const Text('Status: '),
                Chip(
                  label: Text(
                    data['isActive'] == true
                        ? isExpired
                            ? 'Expired'
                            : 'Active'
                        : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: data['isActive'] == true
                      ? isExpired
                          ? Colors.orange
                          : Colors.green
                      : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
