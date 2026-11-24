import 'package:flutter/material.dart';

/// Compact dark bottom navigation with persistent visible tab labels.
/// Navigation ownership remains with HomePage; no player or API logic here.
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.items,
    this.backgroundColor,
    this.currentIndex = 0,
    this.onTap,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedColorOpacity,
    this.itemShape = const StadiumBorder(),
    this.margin = const EdgeInsets.all(8),
    this.itemPadding = const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  });

  final List<CustomBottomNavBarItem> items;
  final int currentIndex;
  final Function(int)? onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? selectedColorOpacity;
  final ShapeBorder itemShape;
  final EdgeInsets margin;
  final EdgeInsets itemPadding;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final active = selectedItemColor ?? const Color(0xFF1ED760);
    final inactive = unselectedItemColor ?? const Color(0xFFB3B3B3);
    return ColoredBox(
      color: backgroundColor ?? const Color(0xFF101010),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: currentIndex == i,
                child: InkWell(
                  onTap: () => onTap?.call(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: itemPadding,
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: curve,
                      style: TextStyle(
                        color: currentIndex == i ? active : inactive,
                        fontSize: 10,
                        fontWeight: currentIndex == i
                            ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              color: currentIndex == i ? active : inactive,
                              size: 25,
                            ),
                            child: currentIndex == i
                                ? (items[i].activeIcon ?? items[i].icon)
                                : items[i].icon,
                          ),
                          const SizedBox(height: 3),
                          DefaultTextStyle.merge(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            child: items[i].title,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CustomBottomNavBarItem {
  final Widget icon;
  final Widget? activeIcon;
  final Widget title;
  final Color? selectedColor;
  final Color? unselectedColor;

  CustomBottomNavBarItem({
    required this.icon,
    required this.title,
    this.selectedColor,
    this.unselectedColor,
    this.activeIcon,
  });
}
