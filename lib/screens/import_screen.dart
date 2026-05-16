import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/services/parser_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true, // Garante leitura de bytes multiplataforma
    );
    if (result != null) {
      final file = result.files.first;
      if (file.bytes == null) return;
      
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao ler CSV: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickMD() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt'],
      withData: true,
    );
    if (result != null) {
      final file = result.files.first;
      if (file.bytes == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ciclo importado com sucesso! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _csvFile = null;
          _mdFile = null;
          _previewRows = [];
          _cicloController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Logo
            Row(
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            const Text(
              'Importar Treinos',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.84,
              ),
            ),
            const SizedBox(height: 32),

            // Section label
            Text(
              'NOME DO CICLO',
              style: AppTheme.monoStyle.copyWith(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cicloController,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Inter'),
              decoration: InputDecoration(
                hintText: 'Ex: MARATONA DE SP - 2026',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
                fillColor: AppColors.surface,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Section label
            Text(
              'UPLOAD DE ARQUIVOS',
              style: AppTheme.monoStyle.copyWith(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),

            // Stack de Uploads
            Column(
              children: [
                _buildUploadCard(
                  title: 'Planilha de Treino',
                  subtitle: _previewRows.isNotEmpty
                      ? '${_previewRows.length} treinos detectados'
                      : 'Calendário macro e ritmos sugeridos',
                  fileLabel: _csvFile?.name ?? 'PLANEJAMENTO_TREINO.CSV',
                  icon: LucideIcons.fileSpreadsheet,
                  onTap: _pickCSV,
                  isDone: _previewRows.isNotEmpty,
                ),
                const SizedBox(height: 20),
                _buildUploadCard(
                  title: 'Detalhes Técnicos',
                  subtitle: _mdContent != null
                      ? 'Arquivo carregado com sucesso'
                      : 'Guia de ritmos e descrição das séries',
                  fileLabel: _mdFile?.name ?? 'DETALHAMENTO_TREINO.MD',
                  icon: LucideIcons.fileText,
                  onTap: _pickMD,
                  isDone: _mdContent != null,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Preview
            if (_previewRows.isNotEmpty) ...[
              Text(
                'PREVIEW DOS TREINOS',
                style: AppTheme.monoStyle.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
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
                      title: Text(
                        row.prioridade1 ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Dia ${row.diaNumero} - ${row.dataTreino}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              if (_previewRows.length > 5)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      '+ ${_previewRows.length - 5} treinos no calendário',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],

            // Caixa de Confirmação inferior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'Certifique-se de que os arquivos seguem o padrão técnico estabelecido.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: (_previewRows.isEmpty || _isLoading) ? null : _handleImport,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: AppColors.bg)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.check, size: 18, color: AppColors.bg),
                                SizedBox(width: 8),
                                Text(
                                  'Confirmar Importação',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required String fileLabel,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDone,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: isDone ? AppColors.accent.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDone ? AppColors.accent.withOpacity(0.5) : AppColors.border,
                ),
              ),
              child: Icon(
                icon,
                color: isDone ? AppColors.accent : AppColors.muted,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // File Label Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                fileLabel.toUpperCase(),
                style: AppTheme.monoStyle.copyWith(
                  color: isDone ? AppColors.accent : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
