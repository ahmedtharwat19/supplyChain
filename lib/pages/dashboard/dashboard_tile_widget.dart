import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dashboard_metrics.dart';

class DashboardTileWidget extends StatelessWidget {
  final DashboardMetric metric;
  final Map<String, dynamic> data;

  const DashboardTileWidget({
    super.key,
    required this.metric,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // نحصل على القيمة كنص من الدالة valueBuilder باستخدام البيانات
    final value = metric.valueBuilder(data);
    // نحصل على نسبة التقدم (progress) ونقيدها بين 0 و 1
    final progress = metric.progressBuilder(data).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => context.go(metric.route), // الانتقال للمسار المحدد عند الضغط
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(metric.icon, size: 26, color: metric.color),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: metric.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(metric.titleKey), // ترجمة عنوان العنصر
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: metric.color,
                minHeight: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
