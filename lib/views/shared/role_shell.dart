import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Five-item bottom navigation shared by all three role dashboards.
/// Wide layouts (tablets) switch to a NavigationRail automatically.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.shell,
    required this.destinations,
  });

  final StatefulNavigationShell shell;
  final List<ShellDestination> destinations;

  void _go(int index) => shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }
        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            destinations: destinations
                .map(
                  (d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
