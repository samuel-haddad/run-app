import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/models/models.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/services/parser_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Treino treino;
  const WorkoutDetailScreen({super.key, required this.treino});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _anotacaoController = TextEditingController();
  bool _isLoading = false;
  bool _isConcluido = false;
  Detalhamento? _detalhamento;
  SecaoTreino? _secaoPrincipal;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      
      // Buscar ciclo para pegar o MD
      final cicloData = await SupabaseService.client
          .from('ciclos')
          .select('detalhamento_md')
          .eq('id', widget.treino.cicloId)
          .single();

      if (cicloData['detalhamento_md'] != null) {
        final detail = ParserService.parseMarkdown(cicloData['detalhamento_md']);
        setState(() {
          _detalhamento = detail;
          // Tentar encontrar seção (A, B, C) que combine com prioridade_2
          if (widget.treino.prioridade2 != null) {
            _secaoPrincipal = detail.secoes.where((s) => widget.treino.prioridade2!.contains(s.letra)).firstOrNull;
          }
        });
      }

      // Buscar se já está concluído
      final registroData = await SupabaseService.client
          .from('registros')
          .select()
          .eq('treino_id', widget.treino.id)
          .maybeSingle();

      if (registroData != null) {
        setState(() {
          _isConcluido = true;
          _anotacaoController.text = registroData['anotacao'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar detalhes: $e');
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      
      await SupabaseService.client.from('registros').upsert({
        'treino_id': widget.treino.id,
        'user_id': userId,
        'anotacao': _anotacaoController.text.trim(),
        'concluido_em': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino registrado! ✓')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          DateFormat('EEEE, d MMM', 'pt_BR').format(widget.treino.dataTreino).toUpperCase(),
          style: AppTheme.monoStyle.copyWith(color: AppColors.muted),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.treino.prioridade1 ?? 'Sem título', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 24),

            // Guia de Ritmos
            if (_detalhamento?.guiaRitmos != null) ...[
              const Text('GUIA DE RITMOS', style: AppTheme.monoStyle),
              const SizedBox(height: 12),
              _buildRhythmCard(_detalhamento!.guiaRitmos!),
              const SizedBox(height: 32),
            ],

            // Série Principal
            const Text('SÉRIE DO DIA', style: AppTheme.monoStyle),
            const SizedBox(height: 12),
            _buildSeriesCard(),
            const SizedBox(height: 32),

            // Registro
            const Text('REGISTRO', style: AppTheme.monoStyle),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Como foi o treino?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _anotacaoController,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Ex: Senti cansaço no final...'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading ? const CircularProgressIndicator(color: AppColors.bg) : Text(_isConcluido ? 'ATUALIZAR REGISTRO' : 'SALVAR RESULTADO'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildRhythmCard(GuiaRitmos guia) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.surface, AppColors.surface2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            children: guia.ritmos.map((r) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nome, style: AppTheme.monoStyle.copyWith(color: AppColors.muted, fontSize: 10)),
                Text(r.valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent)),
              ],
            )).toList(),
          ),
          if (guia.descricao != null) ...[
            const Divider(color: AppColors.border),
            Text(guia.descricao!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildSeriesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_secaoPrincipal?.titulo ?? widget.treino.prioridade2 ?? 'Principal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Badge(label: Text('CORRIDA'), backgroundColor: AppColors.accentMuted),
            ],
          ),
          if (_secaoPrincipal?.subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_secaoPrincipal!.subtitulo!, style: const TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          if (_secaoPrincipal != null)
            ..._secaoPrincipal!.exercicios.map((ex) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: CircleAvatar(radius: 3, backgroundColor: AppColors.accent)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ex, style: const TextStyle(height: 1.4))),
                ],
              ),
            )),
          if (_secaoPrincipal == null && widget.treino.prioridade1 != null)
            Text(widget.treino.prioridade1!, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}
