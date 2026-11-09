import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';

/// One tab of [AppBottomBar].
class AppBarItem {
  const AppBarItem(this.icon, this.activeIcon, this.label, {this.badge = 0});

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Red counter on the icon (0 = hidden).
  final int badge;
}

/// Floating bottom navigation: a pill indicator glides between tabs, the
/// active icon bounces, optional badges count unread items.
///
/// Shared by the client and driver shells (admin uses a drawer).
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.dark = false,
  });

  final List<AppBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Dark variant for the driver app.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.surfaceDark : AppColors.surface;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: dark ? Colors.white10 : AppColors.line)),
        boxShadow: const [
          BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Gliding pill behind the active tab.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: width * currentIndex + width / 2 - 30,
                    top: 8,
                    child: Container(
                      width: 60,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dark ? AppColors.brand.withValues(alpha: .16) : AppColors.brandSoft,
                        borderRadius: AppRadius.rPill,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            item: items[i],
                            selected: currentIndex == i,
                            dark: dark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelect(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.selected, required this.onTap, required this.dark});

  final AppBarItem item;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = dark ? AppColors.brand : AppColors.brandDeep;
    final idle = dark ? Colors.white54 : AppColors.faint;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: Badge(
                isLabelVisible: item.badge > 0,
                label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
                backgroundColor: AppColors.danger,
                child: AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Icon(selected ? item.activeIcon : item.icon, size: 23, color: selected ? active : idle),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? (dark ? Colors.white : AppColors.ink) : idle,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
