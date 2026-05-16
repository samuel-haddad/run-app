import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/screens/planning_screen.dart';
import 'package:run_app/screens/stats_screen.dart';
import 'package:run_app/screens/import_screen.dart';
import 'package:run_app/screens/workout_detail_screen.dart';
import 'package:run_app/models/models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Treino? _activeWorkout;

  void setActiveWorkout(Treino? treino) {
    setState(() {
      _activeWorkout = treino;
      _currentIndex = 1; // Mudar para a aba de Treino (índice 1)
    });
  }

  void resetToPlanning() {
    setState(() {
      _currentIndex = 0;
    });
  }

  List<Widget> get _screens => [
    const PlanningScreen(),
    WorkoutDetailScreen(
      treino: _activeWorkout,
      onBack: resetToPlanning,
    ),
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
          selectedLabelStyle: AppTheme.monoStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTheme.monoStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.calendar), label: 'Plano'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Treino'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.barChart2), label: 'Stats'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.uploadCloud), label: 'Upload'),
          ],
        ),
      ),
    );
  }
}
