import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/screens/planning_screen.dart';
import 'package:run_app/screens/stats_screen.dart';
import 'package:run_app/screens/import_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PlanningScreen(),
    const StatsScreen(),
    const ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 72 + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          color: AppColors.bg,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.muted,
          selectedLabelStyle: AppTheme.monoStyle.copyWith(fontSize: 10),
          unselectedLabelStyle: AppTheme.monoStyle.copyWith(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.calendar), label: 'PLANO'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.barChart2), label: 'STATS'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.uploadCloud), label: 'UPLOAD'),
          ],
        ),
      ),
    );
  }
}
