import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/dimensions.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView(
      padding: const EdgeInsets.all(kSpacingM),
      children: [
        // Skeleton Hero Card
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(kRadiusL),
            ),
          ),
        ),
        const SizedBox(height: kSpacingL),
        
        // Activity List Placeholder
        ...List.generate(4, (index) => Padding(
          padding: const EdgeInsets.only(bottom: kSpacingM),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor),
                ),
                const SizedBox(width: kSpacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: double.infinity, color: baseColor),
                      const SizedBox(height: kSpacingS),
                      Container(height: 14, width: 100, color: baseColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
