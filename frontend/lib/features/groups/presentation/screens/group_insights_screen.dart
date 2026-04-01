import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/group_analytics_provider.dart';

class GroupInsightsScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;
  const GroupInsightsScreen({super.key, required this.groupId, required this.groupName});

  @override
  ConsumerState<GroupInsightsScreen> createState() => _GroupInsightsScreenState();
}

class _GroupInsightsScreenState extends ConsumerState<GroupInsightsScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(groupAnalyticsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.groupName} Insights')),
      body: analyticsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading insights: $err')),
        data: (data) {
          if (data.spendingByCategory.isEmpty && data.leaderboard.isEmpty) {
            return const Center(child: Text('No analytical data available yet.'));
          }

          final totalSpent = data.spendingByCategory.fold(0.0, (sum, item) => sum + (item['totalCents'] / 100));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spending by Category', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                if (data.spendingByCategory.isNotEmpty)
                  SizedBox(
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 60,
                            sections: List.generate(data.spendingByCategory.length, (i) {
                              final item = data.spendingByCategory[i];
                              final isTouched = i == touchedIndex;
                              final radius = isTouched ? 60.0 : 50.0;
                              final val = (item['totalCents'] / 100) as double;
                              final pct = (val / totalSpent) * 100;

                              return PieChartSectionData(
                                color: _colorFromHex(item['color'] ?? '#9E9E9E'),
                                value: val,
                                title: isTouched ? '\$${val.toStringAsFixed(0)}' : '${pct.toStringAsFixed(0)}%',
                                radius: radius,
                                titleStyle: TextStyle(
                                  fontSize: isTouched ? 18.0 : 14.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total'),
                            Text('\$${totalSpent.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
                
                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: data.spendingByCategory.map((item) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: _colorFromHex(item['color'] ?? '#9E9E9E'), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(item['categoryName'] ?? 'Uncategorized'),
                      ],
                    );
                  }).toList(),
                ),

                const SizedBox(height: 48),
                Text('Leaderboard (Who Paid Highest)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                
                ...data.leaderboard.map((payer) {
                  final amt = payer['totalPaidCents'] / 100 as double;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(payer['userName'][0] ?? '?')),
                    title: Text(payer['userName']),
                    trailing: Text('\$${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add alpha
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
