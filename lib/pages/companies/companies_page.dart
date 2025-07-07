import 'dart:typed_data';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart'; // استيراد go_router
//import 'edit_company_page.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  String searchQuery = '';
  List<String> userCompanyIds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserCompanies();
  }

  Future<void> loadUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        // إذا لم يكن هناك مستخدم، أعد التوجيه إلى صفحة تسجيل الدخول
        context.go('/login');
      }
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;

    final data = doc.data();

    setState(() {
      userCompanyIds = (data?['companyIds'] as List?)?.cast<String>() ?? [];
      isLoading = false;
    });
  }

  Future<void> _confirmDeleteCompany(DocumentSnapshot company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه الشركة؟ سيتم حذف اللوجو أيضًا إن وجد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await company.reference.delete();
        // إزالة معرف الشركة من قائمة المستخدم
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'companyIds': FieldValue.arrayRemove([company.id]),
          });
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الشركة')));
        await loadUserCompanies(); // إعادة تحميل الشركات بعد الحذف
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e')),
          );
        }
      }
    }
  }

  void _editCompany(DocumentSnapshot company) {
    final data = company.data() as Map<String, dynamic>;
    // استخدام go_router للانتقال
    context.push('/edit-company/${company.id}', extra: data).then((_) => loadUserCompanies());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('company_list'.tr()), // استخدام الترجمة
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'add_company'.tr(), // استخدام الترجمة
            onPressed: () {
              context.push('/add-company').then((_) => loadUserCompanies()); // استخدام go_router
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userCompanyIds.isEmpty
              ? const Center(child: Text('لا توجد شركات مرتبطة بك بعد. يرجى إضافة شركة جديدة.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('companies').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد شركات مسجلة في النظام.'));
                    }

                    final companies = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nameAr = (data['name_ar'] ?? '').toString().toLowerCase();
                      final nameEn = (data['name_en'] ?? '').toString().toLowerCase();
                      return userCompanyIds.contains(doc.id) &&
                          (nameAr.contains(searchQuery) || nameEn.contains(searchQuery));
                    }).toList();

                    if (companies.isEmpty) {
                      return const Center(child: Text('لا توجد شركات تطابق البحث أو مرتبطة بحسابك.'));
                    }

                    return ListView.builder(
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        final data = company.data() as Map<String, dynamic>;

                        Uint8List? imageBytes;
                        try {
                          if (data['logo_base64'] != null && data['logo_base64'].toString().isNotEmpty) {
                            imageBytes = base64Decode(data['logo_base64']);
                          }
                        } catch (_) {
                          // Handle decoding error
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          child: ListTile(
                            leading: SizedBox(
                              width: 60,
                              height: 60,
                              child: imageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(imageBytes, fit: BoxFit.contain),
                                    )
                                  : const Icon(Icons.business, size: 40),
                            ),
                            title: Text('${data['name_ar'] ?? ''} - ${data['name_en'] ?? ''}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['address'] != null) Text('📍 ${data['address']}'),
                                if (data['manager_name'] != null) Text('👤 ${data['manager_name']}'),
                                if (data['manager_phone'] != null) Text('📞 ${data['manager_phone']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'تعديل',
                                  onPressed: () => _editCompany(company),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'حذف',
                                  onPressed: () => _confirmDeleteCompany(company),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}