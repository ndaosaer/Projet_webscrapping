import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/comparison_screen.dart';
import 'screens/reviews_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ReviewAnalyzerApp(),
    ),
  );
}

class ReviewAnalyzerApp extends StatelessWidget {
  const ReviewAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Review Analyzer',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.theme,
          home: const MainNavigator(),
        );
      },
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const TrendingScreen(),
    const ComparisonScreen(),
    const ReviewsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1040),
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1040),
              Color(0xFF2d1b69),
              Color(0xFF6b21a8),
              Color(0xFF9333ea),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation, child: child),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.white.withOpacity(0.15),
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Accueil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Recherche',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_fire_department_outlined),
                  selectedIcon: Icon(Icons.local_fire_department_rounded),
                  label: 'Trending',
                ),
                NavigationDestination(
                  icon: Icon(Icons.compare_arrows_outlined),
                  selectedIcon: Icon(Icons.compare_arrows_rounded),
                  label: 'Comparer',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt_rounded),
                  label: 'Avis',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
