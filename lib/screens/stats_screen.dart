import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _total = 0;
  int _concluidos = 0;
  double _percentual = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      
      final treinosData = await SupabaseService.client
          .from('treinos')
          .select('id')
          .eq('user_id', userId);

      final registrosData = await SupabaseService.client
          .from('registros')
          .select('id')
          .eq('user_id', userId);

      setState(() {
        _total = (treinosData as List).length;
        _concluidos = (registrosData as List).length;
        _percentual = _total > 0 ? (_concluidos / _total) * 100 : 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERFORMANCE', style: AppTheme.monoStyle.copyWith(color: AppColors.accent)),
                const SizedBox(height: 4),
                Text('Status', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 32),

                // Grid Stats
                Row(
                  children: [
                    Expanded(child: _buildStatCard('TREINOS', _total.toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('FEITOS', _concluidos.toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('ADESÃO', '${_percentual.toInt()}%')),
                  ],
                ),
                const SizedBox(height: 24),

                // Circular Chart
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 70,
                                startDegreeOffset: -90,
                                sections: [
                                  PieChartSectionData(
                                    color: AppColors.accent,
                                    value: _percentual,
                                    radius: 10,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    color: AppColors.border,
                                    value: 100 - _percentual,
                                    radius: 10,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${_percentual.toInt()}%', style: AppTheme.monoStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.fg)),
                                  Text('CONCLUÍDO', style: AppTheme.monoStyle.copyWith(fontSize: 10, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Text('CONQUISTAS', style: AppTheme.monoStyle),
                const SizedBox(height: 12),
                _buildAchievementItem(LucideIcons.flame, 'Primeiro Ciclo', 'Você iniciou sua jornada!', true),
                _buildAchievementItem(LucideIcons.target, 'Meta Batida', 'Concluiu 5 treinos seguidos', _concluidos >= 5),
                _buildAchievementItem(LucideIcons.trophy, 'Consistência', 'Adesão acima de 80%', _percentual >= 80),
              ],
            ),
          ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.monoStyle.copyWith(fontSize: 24, color: AppColors.accent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.monoStyle.copyWith(fontSize: 9, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(IconData icon, String title, String desc, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: unlocked ? AppColors.accent : AppColors.muted.withOpacity(0.3), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: unlocked ? AppColors.fg : AppColors.muted)),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          if (unlocked) const Icon(LucideIcons.check, color: AppColors.success, size: 16),
        ],
      ),
    );
  }
}
