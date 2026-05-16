import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/models/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _total = 0;
  int _concluidos = 0;
  double _percentual = 0.0;
  List<Treino> _pendingTreinos = [];
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
          .select()
          .eq('user_id', userId)
          .order('data_treino');

      final registrosData = await SupabaseService.client
          .from('registros')
          .select('treino_id')
          .eq('user_id', userId);

      final List<Treino> allTreinos = (treinosData as List).map((json) => Treino.fromJson(json)).toList();
      final Set<String> concluidosIds = (registrosData as List).map((json) => json['treino_id'].toString()).toSet();

      final pending = allTreinos.where((t) => !concluidosIds.contains(t.id)).toList();

      setState(() {
        _total = allTreinos.length;
        _concluidos = concluidosIds.length;
        _percentual = _total > 0 ? (_concluidos / _total) * 100 : 0.0;
        _pendingTreinos = pending;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao buscar estatísticas: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressVal = _percentual.clamp(0.0, 100.0);
    final remainingVal = 100.0 - progressVal;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _fetchStats,
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/runtrack_thumb.svg',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'RunTrack',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                            letterSpacing: -0.48,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Título da Tela
                    const Text(
                      'Status do Treino',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.84,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // VISÃO GERAL Label
                    _buildSectionLabel('VISÃO GERAL'),
                    const SizedBox(height: 16),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('TREINOS', _total.toString())),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('CONCLUÍDOS', _concluidos.toString())),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('PERCENTUAL', '${_percentual.toInt()}%')),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // PERFORMANCE Label
                    _buildSectionLabel('PERFORMANCE'),
                    const SizedBox(height: 16),

                    // Circular Progress Chart Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: Stack(
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 66,
                                  startDegreeOffset: -90,
                                  sections: [
                                    PieChartSectionData(
                                      color: AppColors.accent,
                                      value: progressVal,
                                      radius: 8,
                                      showTitle: false,
                                    ),
                                    PieChartSectionData(
                                      color: AppColors.border,
                                      value: remainingVal,
                                      radius: 8,
                                      showTitle: false,
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_percentual.toInt()}%',
                                      style: AppTheme.monoStyle.copyWith(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'CONCLUÍDO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PENDENTES Label
                    _buildSectionLabel('PENDENTES'),
                    const SizedBox(height: 16),

                    // Pending List
                    if (_pendingTreinos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum treino pendente. Excelente trabalho! 🎉',
                            style: TextStyle(fontSize: 14, color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _pendingTreinos.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Treino t = entry.value;

                          // Formatar diaSemana e dia/mês (ex: Domingo, 10/05)
                          String dateText = DateFormat('EEEE, dd/MM', 'pt_BR').format(t.dataTreino);
                          if (dateText.isNotEmpty) {
                            dateText = dateText[0].toUpperCase() + dateText.substring(1);
                          }

                          final bool isNext = index == 0;
                          final String statusLabel = isNext ? 'PRÓXIMO' : 'PENDENTE';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              border: const Border(
                                left: BorderSide(color: AppColors.border, width: 3),
                                top: BorderSide(color: AppColors.border, width: 1),
                                right: BorderSide(color: AppColors.border, width: 1),
                                bottom: BorderSide(color: AppColors.border, width: 1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.prioridade1 ?? 'Corrida livre',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateText,
                                        style: AppTheme.monoStyle.copyWith(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: AppTheme.monoStyle.copyWith(
        fontSize: 11,
        color: AppColors.accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.monoStyle.copyWith(
              fontSize: 24,
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
