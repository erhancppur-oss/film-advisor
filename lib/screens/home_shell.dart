import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/settings_state.dart';
import 'advisor_screen.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'trends_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<SettingsState>();
    final index = st.tabIndex;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          DiscoverScreen(),
          TrendsScreen(),
          AdvisorScreen(),
          SearchScreen(),
          LibraryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: st.goToTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: s.t('nav_discover'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department_rounded),
            label: s.t('nav_trends'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome_rounded),
            label: s.t('nav_advisor'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            label: s.t('nav_search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmarks_outlined),
            selectedIcon: const Icon(Icons.bookmarks_rounded),
            label: s.t('nav_library'),
          ),
        ],
      ),
    );
  }
}
