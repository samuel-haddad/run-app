import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/models/models.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/screens/workout_detail_screen.dart';
import 'package:run_app/screens/main_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => PlanningScreenState();
}

class PlanningScreenState extends State<PlanningScreen> {
  List<Treino> _treinos = [];
  Set<String> _concluidosIds = {};
  Map<String, String> _cicloNames = {};
  bool _isLoading = true;
  bool _showAll = false;

  // Modo de edição
  bool _isEditMode = false;
  Set<String> _selectedIds = {};

  List<Treino> get _displayedTreinos {
    return _showAll
        ? _treinos
        : _treinos.where((t) => !_concluidosIds.contains(t.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;

      final treinosData = await SupabaseService.client
          .from('treinos')
          .select('*, ciclos(nome)')
          .eq('user_id', userId)
          .order('data_treino', ascending: true);

      final registrosData = await SupabaseService.client
          .from('registros')
          .select('treino_id')
          .eq('user_id', userId);

      setState(() {
        _treinos = (treinosData as List).map((json) {
          final t = Treino.fromJson(json);
          if (json['ciclos'] != null) {
            _cicloNames[t.cicloId] = json['ciclos']['nome'];
          }
          return t;
        }).toList();
        _treinos.sort((a, b) => a.dataTreino.compareTo(b.dataTreino));
        _concluidosIds = (registrosData as List).map((json) => json['treino_id'].toString()).toSet();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar treinos: $e');
      setState(() => _isLoading = false);
    }
  }

  // Toggles completion of a single workout directly from the check button
  Future<void> _toggleSingleCompletion(String id) async {
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final isCompleted = _concluidosIds.contains(id);

      if (isCompleted) {
        await SupabaseService.client.from('registros').delete().eq('treino_id', id);
        setState(() {
          _concluidosIds.remove(id);
        });
      } else {
        await SupabaseService.client.from('registros').upsert({
          'treino_id': id,
          'user_id': userId,
          'concluido_em': DateTime.now().toIso8601String(),
        });
        setState(() {
          _concluidosIds.add(id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  // Completes all selected workouts in bulk
  Future<void> _markAsCompletedBulk(List<String> ids) async {
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final payloads = ids.map((id) => {
        'treino_id': id,
        'user_id': userId,
        'concluido_em': DateTime.now().toIso8601String(),
      }).toList();

      await SupabaseService.client.from('registros').upsert(payloads);
      
      setState(() {
        _concluidosIds.addAll(ids);
        _selectedIds.clear();
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treinos marcados como concluídos com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao concluir treinos em lote: $e')),
        );
      }
    }
  }

  Future<void> _deleteTreinos(List<String> ids) async {
    try {
      for (final id in ids) {
        await SupabaseService.client.from('treinos').delete().eq('id', id);
      }
      setState(() {
        _treinos.removeWhere((t) => ids.contains(t.id));
        _selectedIds.removeAll(ids);
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

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final displayed = _displayedTreinos;
    setState(() {
      if (_selectedIds.length == displayed.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = displayed.map((t) => t.id).toSet();
      }
    });
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Exclusão'),
        content: Text('Excluir $count treino${count != 1 ? 's' : ''}?\nEsta ação não pode ser desfeita e removerá os treinos das métricas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteTreinos(_selectedIds.toList());
      _toggleEditMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: fetchData,
            color: AppColors.accent,
            child: CustomScrollView(
              slivers: [
                // --- Header ---
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/runtrack_thumb.svg',
                                      width: 28,
                                      height: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'RunTrack',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.66,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  DateFormat('EEEE, dd \'de\' MMMM', 'pt_BR').format(DateTime.now()).toUpperCase(),
                                  style: AppTheme.monoStyle.copyWith(color: AppColors.accent, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text('Planejamento', style: Theme.of(context).textTheme.headlineLarge),
                              ],
                            ),
                            // Botão "Tudo" + "Editar/Cancelar"
                            Row(
                              children: [
                                if (_isEditMode) ...[
                                  _buildHeaderButton(
                                    label: 'Tudo',
                                    onTap: _selectAll,
                                    isOutline: true,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                _buildHeaderButton(
                                  label: _isEditMode ? 'Cancelar' : 'Editar',
                                  onTap: _toggleEditMode,
                                  isActive: _isEditMode,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildShowAllSwitch(),
                      ],
                    ),
                  ),
                ),

                // --- Lista de Treinos ---
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  )
                else if (_displayedTreinos.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.calendar, size: 48, color: AppColors.muted.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            _treinos.isEmpty
                                ? 'Nenhum treino importado'
                                : 'Todos os treinos concluídos!',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _treinos.isEmpty
                                ? 'Vá em Upload para começar'
                                : 'Ative "Mostrar todos os treinos" para ver o histórico',
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildWorkoutCard(_displayedTreinos[index]),
                        childCount: _displayedTreinos.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // --- Barra de Ação em Lote (aparece ao selecionar em modo edição) ---
          if (_isEditMode && _selectedIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 30)],
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selecionado${_selectedIds.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _markAsCompletedBulk(_selectedIds.toList()),
                      child: const Text('Concluído'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _confirmBulkDelete,
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required String label, required VoidCallback onTap, bool isOutline = false, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isOutline ? AppColors.border : (isActive ? AppColors.accent : AppColors.border)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : (isOutline ? AppColors.muted : AppColors.accent),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.monoStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildWorkoutCard(Treino treino) {
    final hoje = _isToday(treino.dataTreino);
    final concluido = _concluidosIds.contains(treino.id);
    final selected = _selectedIds.contains(treino.id);
    final cicloNome = _cicloNames[treino.cicloId] ?? 'Ciclo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (_isEditMode) {
            _toggleSelection(treino.id);
          } else {
            final mainState = context.findAncestorStateOfType<MainScreenState>();
            if (mainState != null) {
              mainState.setActiveWorkout(treino);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(treino: treino))).then((_) => fetchData());
            }
          }
        },
        child: Row(
          children: [
            // Indicador de seleção (círculo) — visível só em modo edição
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _isEditMode ? 32 : 0,
              height: 24,
              margin: EdgeInsets.only(right: _isEditMode ? 12 : 0),
              child: _isEditMode
                  ? GestureDetector(
                      onTap: () => _toggleSelection(treino.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.accent : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppColors.accent : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : null,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withOpacity(0.05)
                      : (concluido ? const Color(0xFF132D15).withOpacity(0.15) : AppColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : (hoje
                            ? AppColors.accent
                            : (concluido ? AppColors.success.withOpacity(0.4) : AppColors.border)),
                    width: 1,
                  ),
                  boxShadow: hoje ? [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 20)] : [],
                ),
                child: Stack(
                  children: [
                    // Conteúdo Principal do Card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ciclo Tag
                          Text(
                            cicloNome.toUpperCase(),
                            style: AppTheme.monoStyle.copyWith(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),

                          // Header: dia + data + badge Hoje
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (treino.diaSemana ?? '').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w700, 
                                      color: concluido ? AppColors.success : AppColors.muted
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd/MM').format(treino.dataTreino),
                                    style: AppTheme.monoStyle.copyWith(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (hoje)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('HOJE', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              // Espaço seguro para o botão check absoluto
                              const SizedBox(width: 40),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Título e foco
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      treino.prioridade1 ?? 'Treino',
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.w600, 
                                        letterSpacing: -0.3,
                                        decoration: concluido ? TextDecoration.lineThrough : null,
                                        color: concluido ? AppColors.muted : Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (treino.prioridade2 != null)
                                      Text(
                                        treino.prioridade2!, 
                                        style: TextStyle(
                                          fontSize: 13, 
                                          color: AppColors.muted,
                                          decoration: concluido ? TextDecoration.lineThrough : null,
                                        ), 
                                        overflow: TextOverflow.ellipsis
                                      ),
                                  ],
                                ),
                              ),
                              // Botão seta — escondido no modo edição
                              if (!_isEditMode) ...[
                                const SizedBox(width: 12),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: hoje ? AppColors.accent : AppColors.surface,
                                    border: Border.all(color: hoje ? AppColors.accent : (concluido ? AppColors.success.withOpacity(0.5) : AppColors.border)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.chevronRight, 
                                    size: 18, 
                                    color: hoje ? Colors.black : (concluido ? AppColors.success : AppColors.accent)
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Metadados (Duração / Terreno)
                          if (treino.duracaoTotal != null || treino.terreno != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                              child: Row(
                                children: [
                                  if (treino.duracaoTotal != null) _buildMetaItem('Duração', treino.duracaoTotal!),
                                  if (treino.duracaoTotal != null && treino.terreno != null) const SizedBox(width: 24),
                                  if (treino.terreno != null) _buildMetaItem('Terreno', treino.terreno!),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Botão Check Absoluto no canto superior direito - Oculto no modo edição
                    if (!_isEditMode)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => _toggleSingleCompletion(treino.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: concluido ? AppColors.success : AppColors.surface,
                              border: Border.all(
                                color: concluido ? AppColors.success : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 18,
                              color: concluido ? Colors.black : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowAllSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _showAll ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: _showAll ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 10),
              const Text(
                'Mostrar todos os treinos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Switch.adaptive(
            value: _showAll,
            onChanged: (value) {
              setState(() {
                _showAll = value;
              });
            },
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withOpacity(0.3),
            inactiveThumbColor: AppColors.muted,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}
