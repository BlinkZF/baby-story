import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded,    label: '首页',   path: '/home'),
    _TabItem(icon: Icons.menu_book_rounded, label: '内容', path: '/content'),
    _TabItem(icon: Icons.person_rounded,  label: '我的',   path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current  = _tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = i == current;
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(_tabs[i].path),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_tabs[i].icon, size: 24,
                          color: selected ? AppColors.primary : AppColors.textHint),
                      const SizedBox(height: 2),
                      Text(_tabs[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? AppColors.primary : AppColors.textHint,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({required this.icon, required this.label, required this.path});
}
