import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';

class AdminLicenseManagementPage extends StatefulWidget {
  const AdminLicenseManagementPage({super.key});

  @override
  State<AdminLicenseManagementPage> createState() =>
      _AdminLicenseManagementPageState();
}

class _AdminLicenseManagementPageState
    extends State<AdminLicenseManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  final _licenseService = LicenseService();
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _processRequest(String requestId, bool approve) async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (approve) {
        final requestDoc = await _firestore
            .collection('license_requests')
            .doc(requestId)
            .get();
        final requestData = requestDoc.data();

        if (requestData != null) {
          await _licenseService.generateLicenseKey(
            userId: requestData['userId'],
            durationMonths: requestData['durationMonths'],
            maxDevices: requestData['requestedDevices'],
          );
        }
      }

      await _firestore.collection('license_requests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  approve ? 'request_approved'.tr() : 'request_rejected'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'processing_error'.tr());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${'processing_error'.tr()}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('license_management'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'pending_requests'.tr()),
                      Tab(text: 'issued_licenses'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPendingRequestsView(),
                        _buildIssuedLicensesView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('license_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('error_loading_requests'.tr()));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(child: Text('no_pending_requests'.tr()));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            return _buildRequestCard(requests[index].id, request);
          },
        );
      },
    );
  }

  Widget _buildIssuedLicensesView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('licenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('error_loading_licenses'.tr()));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenses = snapshot.data?.docs ?? [];

        if (licenses.isEmpty) {
          return Center(child: Text('no_issued_licenses'.tr()));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: licenses.length,
          itemBuilder: (context, index) {
            final license = licenses[index].data() as Map<String, dynamic>;
            return _buildLicenseCard(license);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'user_id'.tr()}: ${request['userId']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${'devices_requested'.tr()}: ${request['requestedDevices']}'),
            Text('${'duration_months'.tr()}: ${request['durationMonths']}'),
            Text(
                '${'request_date'.tr()}: ${_formatDate(request['createdAt']?.toDate())}'),
            const SizedBox(height: 8),
            if (_isProcessing)
              const LinearProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _processRequest(requestId, false),
                    child: Text(
                      'reject'.tr(),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _processRequest(requestId, true),
                    child: Text('approve'.tr()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard(Map<String, dynamic> license) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              license['licenseKey'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('${'user_id'.tr()}: ${license['userId']}'),
            Text('${'devices_allowed'.tr()}: ${license['maxDevices']}'),
            Text(
                '${'devices_used'.tr()}: ${(license['deviceIds'] as List?)?.length ?? 0}'),
            Text(
                '${'expiration_date'.tr()}: ${_formatDate(DateTime.parse(license['expirationDate']))}'),
            Text(
                '${'status'.tr()}: ${license['isActive'] == true ? 'active'.tr() : 'inactive'.tr()}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'unknown_date'.tr();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
