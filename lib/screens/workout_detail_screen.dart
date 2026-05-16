import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/models/models.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/services/parser_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Treino? treino;
  final VoidCallback? onBack;

  const WorkoutDetailScreen({super.key, this.treino, this.onBack});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _anotacaoController = TextEditingController();
  Treino? _activeTreino;
  bool _isLoading = true;
  bool _isConcluido = false;
  bool _noWorkoutToday = false;
  Detalhamento? _detalhamento;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
  }

  @override
  void didUpdateWidget(covariant WorkoutDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.treino?.id != oldWidget.treino?.id) {
      _loadWorkoutData();
    }
  }

  Future<void> _loadWorkoutData() async {
    setState(() {
      _isLoading = true;
      _noWorkoutToday = false;
      _detalhamento = null;
      _isConcluido = false;
      _anotacaoController.clear();
    });

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      Treino? targetTreino = widget.treino;

      if (targetTreino == null) {
        // Buscar treino do dia atual
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final treinosData = await SupabaseService.client
            .from('treinos')
            .select()
            .eq('user_id', userId)
            .eq('data_treino', todayStr)
            .maybeSingle();

        if (treinosData != null) {
          targetTreino = Treino.fromJson(treinosData);
        } else {
          setState(() {
            _noWorkoutToday = true;
            _isLoading = false;
          });
          return;
        }
      }

      _activeTreino = targetTreino;

      // 1. Buscar status de conclusão (registros)
      final registroData = await SupabaseService.client
          .from('registros')
          .select()
          .eq('treino_id', targetTreino.id)
          .maybeSingle();

      if (registroData != null) {
        _isConcluido = true;
        _anotacaoController.text = registroData['anotacao'] ?? '';
      }

      // 2. Buscar o detalhamento bruto em Markdown do ciclo
      final cicloData = await SupabaseService.client
          .from('ciclos')
          .select('detalhamento_md')
          .eq('id', targetTreino.cicloId)
          .single();

      final String? md = cicloData['detalhamento_md'];

      if (md != null) {
        final detail = ParserService.parseMarkdown(md);
        _detalhamento = detail;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do treino: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_activeTreino == null) return;
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;

      await SupabaseService.client.from('registros').upsert({
        'treino_id': _activeTreino!.id,
        'user_id': userId,
        'anotacao': _anotacaoController.text.trim(),
        'concluido_em': DateTime.now().toIso8601String(),
      });

      setState(() {
        _isConcluido = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado salvo com sucesso! ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleCompletion(bool completed) async {
    if (_activeTreino == null) return;
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      if (completed) {
        await SupabaseService.client.from('registros').upsert({
          'treino_id': _activeTreino!.id,
          'user_id': userId,
          'concluido_em': DateTime.now().toIso8601String(),
        });
        setState(() {
          _isConcluido = true;
        });
      } else {
        await SupabaseService.client.from('registros').delete().eq('treino_id', _activeTreino!.id);
        setState(() {
          _isConcluido = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar conclusão: $e')));
      }
    }
  }

  Future<void> _deleteTreino() async {
    if (_activeTreino == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Deletar Treino'),
        content: const Text('Deseja excluir este treino permanentemente? Esta ação removerá o treino de todas as estatísticas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.client.from('treinos').delete().eq('id', _activeTreino!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino excluído permanentemente!')));
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir treino: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRichText(String text) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: AppTheme.monoStyle.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  String? _getTargetLetter() {
    final p2 = _activeTreino?.prioridade2;
    if (p2 == null) return null;
    final match = RegExp(r'Treino\s+([A-Z])', caseSensitive: false).firstMatch(p2);
    return match?.group(1)?.toUpperCase();
  }

  Widget _buildRhythmCard(GuiaRitmos guia) {
    String paceLabel = 'Pace E / L';
    String paceValue = '5:49 - 6:35';
    String effortValue = 'Leve';
    String? rhythmDesc;

    for (var r in guia.ritmos) {
      final name = r.nome.toLowerCase();
      if (name.contains('ritmo') || name.contains('pace')) {
        paceLabel = r.nome;
        paceValue = r.valor;
      } else if (name.contains('esforço') || name.contains('esforco')) {
        final val = r.valor;
        final dotIndex = val.indexOf('.');
        if (dotIndex != -1) {
          effortValue = val.substring(0, dotIndex).trim();
          rhythmDesc = val.substring(dotIndex + 1).trim();
        } else {
          effortValue = val;
        }
      }
    }

    if (rhythmDesc == null && guia.descricao != null) {
      rhythmDesc = guia.descricao;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            Color(0xFF131D26),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paceLabel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            paceValue,
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESFORÇO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            effortValue,
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (rhythmDesc != null && rhythmDesc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    rhythmDesc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesSection() {
    final targetLetter = _getTargetLetter();
    final secao = _detalhamento?.secoes.where((s) => s.letra == targetLetter).firstOrNull;

    if (secao == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _activeTreino?.prioridade2 ?? 'Fortalecimento',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(4)),
                  child: const Text('COMPLEMENTO', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _activeTreino?.prioridade2 ?? 'Nenhuma série de fortalecimento hoje.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  secao.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  secao.letra == 'A'
                      ? 'CORE & SUPERIOR'
                      : (secao.letra == 'B' ? 'BASE DE FORÇA' : 'CORE & POTÊNCIA'),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (secao.subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              secao.subtitulo!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Column(
            children: secao.exercicios.map((ex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8, right: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: _buildRichText(ex),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como foi o treino de hoje?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _anotacaoController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              hintText: 'Ex: Senti um pouco de cansaço no final, mas o pace foi estável...',
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SALVAR RESULTADO'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF2C1315).withOpacity(0.4),
                foregroundColor: const Color(0xFFFF8B8B),
                side: const BorderSide(color: Color(0xFF5C262A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onPressed: _deleteTreino,
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('DELETAR TREINO'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_noWorkoutToday) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 48),
                const Icon(LucideIcons.smile, size: 64, color: AppColors.accent),
                const SizedBox(height: 24),
                const Text(
                  'Nenhum treino para hoje.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aproveite o descanso.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Logo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 24),

            // Ciclo Tag
            Text(
              'CICLO 1',
              style: AppTheme.monoStyle.copyWith(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),

            // Header (Back button + Title)
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activeTreino != null
                        ? '${_activeTreino!.diaSemana ?? ''}, ${DateFormat('dd/MM').format(_activeTreino!.dataTreino)}'
                        : 'Treino do Dia',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Completion Header Toggle switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isConcluido ? const Color(0xFF132D15).withOpacity(0.08) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConcluido ? AppColors.success : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isConcluido ? AppColors.success : AppColors.muted,
                      boxShadow: _isConcluido
                          ? [BoxShadow(color: AppColors.success.withOpacity(0.6), blurRadius: 8)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isConcluido ? 'Treino concluído' : 'Treino não concluído',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isConcluido,
                    onChanged: _toggleCompletion,
                    activeColor: AppColors.success,
                    activeTrackColor: AppColors.success.withOpacity(0.3),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: AppColors.border,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Rhythm Guide Section
            if (_detalhamento?.guiaRitmos != null) ...[
              const Text(
                'GUIA DE RITMOS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildRhythmCard(_detalhamento!.guiaRitmos!),
              const SizedBox(height: 28),
            ],

            // Series Section
            const Text(
              'SÉRIE DO DIA',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            _buildSeriesSection(),
            const SizedBox(height: 28),

            // Registry Section
            const Text(
              'REGISTRO',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeedbackSection(),
          ],
        ),
      ),
    );
  }
}
