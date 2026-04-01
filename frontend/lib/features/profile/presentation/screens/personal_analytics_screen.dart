import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/theme/app_colors.dart';

final personalAnalyticsProvider = FutureProvider.family<List<dynamic>, String>((ref, range) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/analytics/personal?range=$range');
  if (res.data['success'] == true) {
    return res.data['data']['timeline'] as List<dynamic>;
  }
  return [];
});

class PersonalAnalyticsScreen extends ConsumerStatefulWidget {
  const PersonalAnalyticsScreen({super.key});

  @override
  ConsumerState<PersonalAnalyticsScreen> createState() => _PersonalAnalyticsScreenState();
}

class _PersonalAnalyticsScreenState extends ConsumerState<PersonalAnalyticsScreen> {
  String _selectedRange = 'ytd';

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(personalAnalyticsProvider(_selectedRange));

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Analytics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'month', label: Text('1M')),
                ButtonSegment(value: 'ytd', label: Text('YTD')),
                ButtonSegment(value: 'all', label: Text('All Time')),
              ],
              selected: {_selectedRange},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _selectedRange = newSelection.first);
              },
            ),
          ),
          
          Expanded(
            child: timelineAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (timeline) {
                if (timeline.isEmpty) {
                  return const Center(child: Text('No activity found for this period.'));
                }

                List<FlSpot> spots = [];
                double minX = double.infinity;
                double maxX = double.negativeInfinity;
                double minY = double.infinity;
                double maxY = double.negativeInfinity;

                for (int i = 0; i < timeline.length; i++) {
                  final x = i.toDouble();
                  final y = (timeline[i]['cumulativeDebtCents'] / 100) as double;
                  spots.add(FlSpot(x, y));

                  if (x < minX) minX = x;
                  if (x > maxX) maxX = x;
                  if (y < minY) minY = y;
                  if (y > maxY) maxY = y;
                }

                // add padding
                minY -= 50;
                maxY += 50;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cumulative Debt Timeline', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 32),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false), // Hide date labels for simplicity
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: minX,
                            maxX: maxX,
                            minY: minY,
                            maxY: maxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: AppColors.primary500,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary500.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Positive values indicate you owe money. Negative means you are owed.', 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                         textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      )
    );
  }
}
