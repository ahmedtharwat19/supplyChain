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

  // دالة لجعل اللون شفاف بنسبة معينة
  Color _withOpacity(Color color, double opacity) {
    return color.withAlpha((opacity * 255).round());
  }

  @override
  Widget build(BuildContext context) {
    final value = metric.valueBuilder(data);
    final progress = metric.progressBuilder(data).clamp(0.0, 1.0);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: highlight
            ? BorderSide(color: _withOpacity(Colors.orange, 0.8), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => context.go(metric.route),
        child: Container(
          width: isMobile ? 160 : 200,
          padding: const EdgeInsets.all(12),
          
          // استخدم Expanded أو Flexible داخل العمود لمنع overflow
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _withOpacity(metric.color, 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  metric.icon,
                  size: isMobile ? 28 : 32,
                  color: metric.color,
                ),
              ),
              const SizedBox(height: 12),
              // FittedBox لمنع النص من التمدد الزائد
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.isNotEmpty ? value : 'No Data',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: metric.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(metric.titleKey),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isMobile ? 16 : 18,
                        height: 1.3,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: _withOpacity(Colors.grey, 0.2),
                  color: metric.color,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
