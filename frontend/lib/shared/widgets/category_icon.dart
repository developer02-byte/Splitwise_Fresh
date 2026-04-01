import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;
  final bool circular;

  const CategoryIcon({
    super.key,
    required this.icon,
    this.size = 24.0,
    this.color,
    this.circular = true,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, IconData> iconMap = {
      'restaurant_rounded': Icons.restaurant_rounded,
      'directions_car_rounded': Icons.directions_car_rounded,
      'home_rounded': Icons.home_rounded,
      'bolt_rounded': Icons.bolt_rounded,
      'school_rounded': Icons.school_rounded,
      'airplanemode_active_rounded': Icons.airplanemode_active_rounded,
      'medical_services_rounded': Icons.medical_services_rounded,
      'shopping_bag_rounded': Icons.shopping_bag_rounded,
      'movie_rounded': Icons.movie_rounded,
      'category_rounded': Icons.category_rounded,
    };

    final iconData = iconMap[icon] ?? Icons.category_rounded;
    final themeColor = color ?? Theme.of(context).colorScheme.primary;

    if (!circular) return Icon(iconData, size: size, color: themeColor);

    return Container(
      width: size * 1.8,
      height: size * 1.8,
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(iconData, size: size, color: themeColor),
      ),
    );
  }
}
