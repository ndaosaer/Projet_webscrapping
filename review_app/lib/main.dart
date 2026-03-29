import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'providers/theme_provider.dart';
import 'ocean_colors.dart';
import 'glass_widgets.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/comparison_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/map_screen.dart';
import 'screens/categories_screen.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: const ReviewAnalyzerApp(),
  ));
}

class ReviewAnalyzerApp extends StatelessWidget {
  const ReviewAnalyzerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, tp, __) => MaterialApp(
        title: 'Review Analyzer',
        debugShowCheckedModeBanner: false,
        theme: tp.theme,
        home: const MainNavigator(),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    CategoriesScreen(),
    TrendingScreen(),
    ComparisonScreen(),
    MapScreen(),
    ReviewsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tp     = Provider.of<ThemeProvider>(context);
    final isDark = tp.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? OceanColors.darkBg1 : Colors.white,
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? OceanColors.darkGradient
              : OceanColors.lightGradient,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: _buildNavBar(isDark, tp),
    );
  }

  Widget _buildNavBar(bool isDark, ThemeProvider tp) {
    final accent = isDark ? OceanColors.cyan : OceanColors.lightBlue;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.white.withOpacity(0.9),
            border: Border(top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : OceanColors.lightBorder,
                width: 0.5)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              indicatorColor: accent.withOpacity(0.15),
              elevation: 0,
              height: 60,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                _dest(Icons.home_outlined,     Icons.home_rounded,              'Accueil',    accent),
                _dest(Icons.search_rounded,    Icons.search_rounded,            'Recherche',  accent),
                _dest(Icons.category_outlined, Icons.category_rounded,          'Catégories', accent),
                _dest(Icons.local_fire_department_outlined,
                      Icons.local_fire_department_rounded,                      'Trending',   accent),
                _dest(Icons.compare_arrows_outlined,
                      Icons.compare_arrows_rounded,                             'Comparer',   accent),
                _dest(Icons.map_outlined,      Icons.map_rounded,               'Carte',      accent),
                _dest(Icons.list_alt_outlined, Icons.list_alt_rounded,          'Avis',       accent),
              ],
            ),
            // Bouton toggle thème compact en bas
            Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 6,
                  top: 2),
              child: GestureDetector(
                onTap: tp.toggleTheme,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 12,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isDark ? 'Mode clair' : 'Mode sombre',
                      style: TextStyle(color: accent, fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins'),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  NavigationDestination _dest(IconData off, IconData on, String label, Color accent) {
    return NavigationDestination(
      icon: Icon(off),
      selectedIcon: Icon(on, color: accent),
      label: label,
    );
  }
}
