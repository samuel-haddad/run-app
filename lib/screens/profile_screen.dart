import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/screens/auth_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Outro';
  String? _avatarUrl;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
        
        final data = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _nameController.text = data['nome'] ?? 'Atleta';
            _selectedGender = data['sexo'] ?? 'Outro';
            _ageController.text = (data['idade'] ?? 18).toString();
            _avatarUrl = data['avatar_url'];
          });
        } else {
          // Se não houver profile (caso raro de falha no trigger), setar defaults
          setState(() {
            _nameController.text = 'Atleta';
            _selectedGender = 'Outro';
            _ageController.text = '18';
            _avatarUrl = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Garante que temos os bytes para upload multiplataforma
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploading = true);

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final extension = file.name.split('.').last.toLowerCase();
      final path = '${user.id}/avatar.$extension';

      // Envia os bytes para o bucket 'avatars' (upsert para substituir anterior)
      await SupabaseService.client.storage.from('avatars').uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      // Obtém URL pública
      final publicUrl = SupabaseService.client.storage.from('avatars').getPublicUrl(path);

      setState(() {
        _avatarUrl = publicUrl;
      });

      // Atualiza também imediatamente o registro no profiles para evitar perda de dados
      await SupabaseService.client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao fazer upload da imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSave() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final String nome = _nameController.text.trim().isEmpty ? 'Atleta' : _nameController.text.trim();
      final String sexo = _selectedGender;
      final int idade = int.tryParse(_ageController.text.trim()) ?? 18;

      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'nome': nome,
        'sexo': sexo,
        'idade': idade,
        'email': _emailController.text,
        'avatar_url': _avatarUrl,
      });

      // Recarrega informações para garantir sincronia perfeita
      _nameController.text = nome;
      _ageController.text = idade.toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil salvo com sucesso! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sair da Conta'),
        content: const Text('Deseja realmente sair da sua conta no RunTrack?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SAIR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String athleteNameDisplay = _nameController.text.trim().isEmpty ? 'Atleta' : _nameController.text;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
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
                  const SizedBox(height: 32),

                  // Título
                  const Text(
                    'Meu Perfil',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.84,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Header / Avatar area
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _isUploading ? null : _pickAndUploadImage,
                              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.accent, width: 3),
                                        image: DecorationImage(
                                          image: NetworkImage(_avatarUrl!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.accent, width: 3),
                                        color: AppColors.surface,
                                      ),
                                      child: const Icon(
                                        Icons.account_circle,
                                        size: 114,
                                        color: AppColors.muted,
                                      ),
                                    ),
                            ),
                            if (_isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: AppColors.accent),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploading ? null : _pickAndUploadImage,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.camera, color: AppColors.bg, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          athleteNameDisplay,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ATLETA NÍVEL 4',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Formulário
                  _buildLabel('Nome Completo'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameController, 'Atleta'),
                  const SizedBox(height: 24),

                  _buildLabel('E-mail'),
                  const SizedBox(height: 8),
                  _buildTextField(_emailController, 'seu@email.com', keyboardType: TextInputType.emailAddress, readOnly: true),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Sexo'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  dropdownColor: AppColors.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Inter'),
                                  icon: const Icon(LucideIcons.chevronDown, color: AppColors.muted),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                                    DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                                    DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedGender = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Idade'),
                            const SizedBox(height: 8),
                            _buildTextField(_ageController, '18', keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Botão Salvar
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
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: AppColors.bg)
                          : const Text(
                              'SALVAR ALTERAÇÕES',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão Sair
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0x33FF453A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleLogout,
                      child: const Text(
                        'Sair da Conta',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String placeholder, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? AppColors.muted : Colors.white,
        fontSize: 16,
        fontFamily: 'Inter',
      ),
      decoration: InputDecoration(
        hintText: placeholder,
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
          borderSide: BorderSide(color: readOnly ? AppColors.border : AppColors.accent),
        ),
      ),
    );
  }
}
