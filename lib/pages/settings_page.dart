import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

const String prefDashboardView = 'dashboard_view';
const String prefSelectedCards = 'selected_cards';

enum DashboardView { short, long }

class SettingsPage extends StatefulWidget {
  final List<String> allCards;

  const SettingsPage({super.key, required this.allCards});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DashboardView _selectedView = DashboardView.short;
  Set<String> _selectedCards = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final viewString = prefs.getString(prefDashboardView) ?? 'short';
    final selectedCards = prefs.getStringList(prefSelectedCards) ?? [];

    setState(() {
      _selectedView =
          viewString == 'long' ? DashboardView.long : DashboardView.short;
      _selectedCards = selectedCards.toSet();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefDashboardView,
        _selectedView == DashboardView.long ? 'long' : 'short');
    await prefs.setStringList(prefSelectedCards, _selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.saved_successfully'))),
      );
    }
  }

/*   void _onViewChanged(DashboardView? value) async {
    if (value == null) return;

    Set<String> selectedCards;
    if (value == DashboardView.long) {
      selectedCards = widget.allCards.toSet(); // اختيار الكل
    } else {
      selectedCards = {
        'total_companies',
        'total_orders',
        'total_amount',
        'total_suppliers',
      };
    }

    setState(() {
      _selectedView = value;
      _selectedCards = selectedCards;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        prefDashboardView, value == DashboardView.long ? 'long' : 'short');
    await prefs.setStringList(prefSelectedCards, selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value == DashboardView.long
                ? tr('settings.long_selected')
                : tr('settings.short_selected'),
          ),
        ),
      );
    }
  } */

void _onViewChanged(DashboardView? value) async {
  if (value == null) return;

  // 🧠 استخدم defaultMenuType لتوليد البطاقات المختارة
  Set<String> selectedCards;
  if (value == DashboardView.long) {
    selectedCards = dashboardMetrics
        .where((metric) => metric.defaultMenuType == 'long')
        .map((metric) => metric.titleKey)
        .toSet();
  } else {
    selectedCards = dashboardMetrics
        .where((metric) => metric.defaultMenuType == 'short')
        .map((metric) => metric.titleKey)
        .toSet();
  }

  setState(() {
    _selectedView = value;
    _selectedCards = selectedCards;
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      prefDashboardView, value == DashboardView.long ? 'long' : 'short');
  await prefs.setStringList(prefSelectedCards, selectedCards.toList());

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value == DashboardView.long
              ? tr('settings.long_selected')
              : tr('settings.short_selected'),
        ),
      ),
    );
  }
}




  void _onCardToggle(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
    });
    _saveSettings();
  }

  void _resetToDefaults() async {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = {
        'totalCompanies',
        'totalOrders',
        'totalAmount',
        'totalSuppliers',
      };
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefDashboardView, 'short');
    await prefs.setStringList(prefSelectedCards, _selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.restored_defaults'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'settings.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('settings.choose_view',
                    style: Theme.of(context).textTheme.headlineMedium)
                .tr(),
            ListTile(
              title: Text('settings.short_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.short,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            ListTile(
              title: Text('settings.long_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.long,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            const Divider(height: 32),
            Text('settings.choose_cards',
                    style: Theme.of(context).textTheme.headlineSmall)
                .tr(),
            Expanded(
              child: ListView(
                children: widget.allCards.map((cardKey) {
                  return CheckboxListTile(
                    title: Text(cardKey).tr(),
                    value: _selectedCards.contains(cardKey),
                    onChanged: (val) {
                      if (val == null) return;
                      _onCardToggle(cardKey, val);
                    },
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save')),
                    onPressed: () async {
                      await _saveSettings();
                      if (!context.mounted) return;
                      Navigator.pop(context, true); // عودة للـ dashboard
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
