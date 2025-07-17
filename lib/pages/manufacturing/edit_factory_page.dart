import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class EditFactoryPage extends StatelessWidget {
  final String factoryId;

  const EditFactoryPage({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context) {
    // Here you would typically fetch the factory details using the factoryId
    // and display them in a form for editing.
    return AppScaffold(
      
        title: tr('edit_factory'),
     
      body: Center(
        child: Text(tr('edit_factory_details', namedArgs: {'id': factoryId})),
      ),
    );
  }
}
