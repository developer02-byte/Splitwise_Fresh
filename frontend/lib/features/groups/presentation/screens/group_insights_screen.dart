import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'providers/group_analytics_provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../shared/widgets/category_icon.dart';

class GroupInsightsScreen extends ConsumerWidget {
  final int groupId;
  final String groupName;

  const GroupInsightsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(groupAnalyticsProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName Insights'),
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(kSpacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending by Category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: kSpacingM),
              _CategoryBreakdownChart(data: data.categoryBreakdown),
              const SizedBox(height: kSpacingL),
              Text(
                'Top Contributors',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: kSpacingM),
              _LeaderboardList(data: data.leaderboard),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownChart extends StatelessWidget {
  final List<CategoryBreakdown> data;

  const _CategoryBreakdownChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(kSpacingXL),
          child: Text('No expense data available yet.'),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _getSections(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((d) => _Indicator(
              color: _getColor(d.categoryId),
              text: d.categoryName,
              isSquare: true,
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    final total = data.fold<int>(0, (sum, item) => sum + item.totalAmount);
    return data.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      final percentage = (d.totalAmount / total) * 100;

      return PieChartSectionData(
        color: _getColor(d.categoryId),
        value: d.totalAmount.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getColor(int id) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[id % colors.length];
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardItem> data;

  const _LeaderboardList({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = data[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
            child: item.avatarUrl == null ? Text(item.userName[0]) : null,
          ),
          title: Text(item.userName),
          trailing: Text(
            '\$${(item.totalPaid / 100).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        )
      ],
    );
  }
}
