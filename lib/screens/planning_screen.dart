import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/models/models.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/screens/workout_detail_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  bool _isLoading = true;
  List<Treino> _treinos = [];
  Map<String, String> _cicloNames = {};
  Set<String> _concluidosIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      
      // Buscar treinos
      final treinosData = await SupabaseService.client
          .from('treinos')
          .select('*, ciclos(nome)')
          .eq('user_id', userId)
          .order('data_treino', ascending: true);

      // Buscar registros (concluídos)
      final registrosData = await SupabaseService.client
          .from('registros')
          .select('treino_id')
          .eq('user_id', userId);

      setState(() {
        _treinos = (treinosData as List).map((json) => Treino.fromJson(json)).toList();
        _concluidosIds = (registrosData as List).map((json) => json['treino_id'].toString()).toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTreino(String id) async {
    try {
      await SupabaseService.client.from('treinos').delete().eq('id', id);
      setState(() {
        _treinos.removeWhere((t) => t.id == id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final todayTreino = _treinos.where((t) => _isToday(t.dataTreino)).firstOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.accent,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM', 'pt_BR').format(DateTime.now()),
                      style: AppTheme.monoStyle.copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: 4),
                    Text('Planejamento', style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
            ),

            if (!_isLoading && todayTreino != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildTodayBanner(todayTreino),
                ),
              ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              )
            else if (_treinos.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.calendar, size: 48, color: AppColors.muted.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('Nenhum treino importado', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Vá em Upload para começar'),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final treino = _treinos[index];
                      return _buildWorkoutCard(treino);
                    },
                    childCount: _treinos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayBanner(Treino treino) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surface.withBlue(40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOJE', style: AppTheme.monoStyle.copyWith(color: AppColors.accent)),
          const SizedBox(height: 4),
          Text(treino.prioridade1 ?? 'Sem título', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (treino.prioridade2 != null)
            Text(treino.prioridade2!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(treino: treino))),
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('VER TREINO'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Treino treino) {
    final hoje = _isToday(treino.dataTreino);
    final concluido = _concluidosIds.contains(treino.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(treino.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(12)),
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excluir treino?'),
              content: const Text('Esta ação não pode ser desfeita.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('EXCLUIR', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          );
        },
        onDismissed: (direction) => _deleteTreino(treino.id),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(treino: treino))),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hoje ? AppColors.accent : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(treino.diaSemana?.toUpperCase() ?? '', style: AppTheme.monoStyle.copyWith(fontSize: 10)),
                        Text(DateFormat('dd/MM').format(treino.dataTreino), style: AppTheme.monoStyle.copyWith(color: AppColors.muted)),
                      ],
                    ),
                    if (concluido)
                      const Icon(LucideIcons.checkCircle, color: AppColors.success, size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(treino.prioridade1 ?? 'Sem título', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (treino.prioridade2 != null)
                  Text(treino.prioridade2!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (treino.duracaoTotal != null) ...[
                      const Icon(LucideIcons.clock, size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(treino.duracaoTotal!, style: AppTheme.monoStyle.copyWith(fontSize: 12)),
                      const SizedBox(width: 16),
                    ],
                    if (treino.terreno != null) ...[
                      const Icon(LucideIcons.mapPin, size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(treino.terreno!, style: AppTheme.monoStyle.copyWith(fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
