import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dashboard_metrics.dart';

class DashboardTileWidget extends StatelessWidget {
  final DashboardMetric metric;
  final Map<String, dynamic> data;
  final bool highlight;

  const DashboardTileWidget({
    super.key,
    required this.metric,
    required this.data,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = metric.valueBuilder(data);
    final progress = metric.progressBuilder(data).clamp(0.0, 1.0);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight
            ? BorderSide(
                color: _withOpacity(Colors.orange, 0.7),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(metric.route),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 150,
            maxWidth: 180,
            minHeight: 200,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _withOpacity(metric.color, 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(metric.icon, size: 20, color: metric.color),
              ),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: metric.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  tr(metric.titleKey),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: _withOpacity(Colors.grey, 0.2),
                    color: metric.color,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لإنشاء ألوان مع opacity بطريقة حديثة
  Color _withOpacity(Color baseColor, double opacity) {
    return baseColor.withAlpha((opacity * 255).round());
  }
}
