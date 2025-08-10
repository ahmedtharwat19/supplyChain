    /*  Future<void> _addCompany() async {
      if (_isLoading) return;

      final nameAr = _nameArController.text.trim();
      final nameEn = _nameEnController.text.trim();
      final address = _addressController.text.trim();
      final managerName = _managerNameController.text.trim();
      final managerPhone = _managerPhoneController.text.trim();

      debugPrint('Starting company add process...');
      debugPrint(
          'Inputs: nameAr="$nameAr", nameEn="$nameEn", address="$address"');

      if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
        debugPrint('Validation failed: required fields missing.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('requierd_fields'.tr())),
        );
        return;
      }

      if (_base64Logo == null || _base64Logo!.isEmpty) {
        debugPrint('Validation failed: logo is missing.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('please_select_logo'.tr())),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        debugPrint('Checking duplicate...');
        final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
        if (isDuplicate) {
          if (!mounted) return;
          debugPrint('Duplicate company detected, aborting add.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (!mounted) return;
          debugPrint('No authenticated user found.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('login_first'.tr())),
          );
          setState(() => _isLoading = false);
          return;
        }
        debugPrint('Authenticated user: ${user.uid}');

        final companyData = {
          'nameAr': nameAr,
          'nameEn': nameEn,
          'address': address,
          'managerName': managerName,
          'managerPhone': managerPhone,
          'logoBase64': _base64Logo,
          'userId': user.uid,
          'createdAt': Timestamp.now(),
        };
        debugPrint('Company data prepared.');

        final firestore = FirebaseFirestore.instance;
        final user = FirebaseAuth.instance.currentUser!;
        final companyId = firestore.collection('companies').doc().id;

        final companyRef = firestore.collection('companies').doc(companyId);
        final userRef = firestore.collection('users').doc(user.uid);

        await firestore.runTransaction((transaction) async {
          transaction.set(companyRef, {
            ...companyData,
            'companyId': companyId, // أضف الـ ID داخل بيانات الشركة
          });

          final userSnap = await transaction.get(userRef);

          if (userSnap.exists) {
            final existingCompanyIds = userSnap.data()?['companyIds'] ?? [];
            transaction.update(userRef, {
              'companyIds': FieldValue.arrayUnion([companyId]),
            });
          } else {
            transaction.set(userRef, {
              'companyIds': [companyId],
            });
          }
        });

        //  debugPrint('Company added with id: ${userSnap}');

        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();
        debugPrint('Fetched user doc for company update.');

        if (userDoc.exists) {
          debugPrint('User doc exists, updating companyIds array...');
          await userDocRef.update({
            'companyIds': FieldValue.arrayUnion([docRef.id]),
          });
        } else {
          debugPrint('User doc does not exist, creating new with companyIds...');
          await userDocRef.set({
            'companyIds': [docRef.id],
          });
        }

        if (!mounted) return;

        debugPrint('Company added and user updated successfully.');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_added_successfully'.tr())),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        // إعادة تحميل الشبكة (يمكن حذفها إذا لم تكن ضرورية)
        await FirebaseFirestore.instance.disableNetwork();
        await FirebaseFirestore.instance.enableNetwork();

        if (!mounted) return;

        final uri = Uri(
          path: '/company-added/${docRef.id}',
          queryParameters: {'nameEn': nameEn},
        );
        debugPrint('Navigating to company added page: $uri');
        context.go(uri.toString());
      } catch (e, stacktrace) {
        debugPrint('Error while adding company: $e');
        debugPrint(stacktrace.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('error_while_adding_company')}: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  */
