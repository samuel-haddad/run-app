import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/services/parser_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _cicloController = TextEditingController();
  PlatformFile? _csvFile;
  PlatformFile? _mdFile;
  List<TreinoRow> _previewRows = [];
  String? _mdContent;
  bool _isLoading = false;

  Future<void> _pickCSV() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx']);
    if (result != null) {
      final file = result.files.first;
      final content = String.fromCharCodes(file.bytes!);
      try {
        final rows = await ParserService.parseCSV(content);
        setState(() {
          _csvFile = file;
          _previewRows = rows;
          if (_cicloController.text.isEmpty) {
            _cicloController.text = file.name.split('.').first.replaceAll('_', ' ').toUpperCase();
          }
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ler CSV: $e')));
      }
    }
  }

  Future<void> _pickMD() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['md', 'txt']);
    if (result != null) {
      final file = result.files.first;
      final content = String.fromCharCodes(file.bytes!);
      setState(() {
        _mdFile = file;
        _mdContent = content;
      });
    }
  }

  Future<void> _handleImport() async {
    if (_previewRows.isEmpty || _cicloController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;

      // 1. Criar Ciclo
      final cicloData = await SupabaseService.client.from('ciclos').insert({
        'user_id': userId,
        'nome': _cicloController.text.trim(),
        'detalhamento_md': _mdContent,
      }).select().single();

      final cicloId = cicloData['id'];

      // 2. Inserir Treinos
      final treinosPayload = _previewRows.map((r) => {
        'ciclo_id': cicloId,
        'user_id': userId,
        'dia_numero': r.diaNumero,
        'dia_semana': r.diaSemana,
        'data_treino': r.dataTreino,
        'prioridade_1': r.prioridade1,
        'prioridade_2': r.prioridade2,
        'terreno': r.terreno,
        'duracao_total': r.duracaoTotal,
      }).toList();

      await SupabaseService.client.from('treinos').insert(treinosPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ciclo importado com sucesso!')));
        setState(() {
          _csvFile = null;
          _mdFile = null;
          _previewRows = [];
          _cicloController.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UPLOAD', style: AppTheme.monoStyle.copyWith(color: AppColors.accent)),
            const SizedBox(height: 4),
            Text('Importar Ciclo', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 32),
            
            // Ciclo Name
            Text('NOME DO CICLO', style: AppTheme.monoStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _cicloController,
              decoration: const InputDecoration(hintText: 'Ex: MARATONA DE SP - 2026'),
            ),
            const SizedBox(height: 32),

            // Files
            _buildUploadCard(
              title: _csvFile?.name ?? 'Planilha de Treinos',
              subtitle: _previewRows.isNotEmpty ? '${_previewRows.length} treinos detectados' : 'CSV ou Excel com o calendário',
              icon: LucideIcons.fileSpreadsheet,
              onTap: _pickCSV,
              isDone: _previewRows.isNotEmpty,
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: _mdFile?.name ?? 'Detalhamento Técnico',
              subtitle: _mdContent != null ? 'Arquivo carregado com sucesso' : 'Markdown com descrição das séries',
              icon: LucideIcons.fileText,
              onTap: _pickMD,
              isDone: _mdContent != null,
            ),
            const SizedBox(height: 32),

            // Preview
            if (_previewRows.isNotEmpty) ...[
              Text('PREVIEW DOS TREINOS', style: AppTheme.monoStyle),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _previewRows.length > 5 ? 5 : _previewRows.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (ctx, i) {
                    final row = _previewRows[i];
                    return ListTile(
                      dense: true,
                      title: Text(row.prioridade1 ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Dia ${row.diaNumero} - ${row.dataTreino}'),
                    );
                  },
                ),
              ),
              if (_previewRows.length > 5)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(child: Text('+ ${_previewRows.length - 5} treinos', style: const TextStyle(color: AppColors.muted))),
                ),
            ],
            
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (_previewRows.isEmpty || _isLoading) ? null : _handleImport,
              child: _isLoading ? const CircularProgressIndicator(color: AppColors.bg) : const Text('CONFIRMAR IMPORTAÇÃO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap, required bool isDone}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDone ? AppColors.accent.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDone ? AppColors.accent : AppColors.border, style: isDone ? BorderStyle.solid : BorderStyle.none),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isDone ? AppColors.accent : AppColors.muted),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            if (isDone) const Icon(LucideIcons.checkCircle2, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
