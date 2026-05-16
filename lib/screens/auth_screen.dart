import 'package:flutter/material.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/screens/main_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await SupabaseService.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await SupabaseService.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verifique seu e-mail para confirmar o cadastro!')),
          );
          setState(() => _isLogin = true);
        }
      }

      if (mounted && SupabaseService.client.auth.currentUser != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: AppColors.danger),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Logo + Nome
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: const Icon(LucideIcons.activity, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Run App',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Text(
                    _isLogin ? 'Boas-vindas de volta' : 'Criar sua conta',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Entre para ver seus treinos' : 'Comece sua jornada hoje',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // E-mail
                  const Text('E-mail', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(hintText: 'seu@email.com'),
                  ),
                  const SizedBox(height: 20),

                  // Senha
                  const Text('Senha', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                  const SizedBox(height: 32),

                  // Botão
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(_isLogin ? 'ENTRAR' : 'CRIAR CONTA'),
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: AppColors.muted, fontSize: 14),
                          children: [
                            TextSpan(text: _isLogin ? 'Não tem conta? ' : 'Já tem conta? '),
                            TextSpan(
                              text: _isLogin ? 'Criar conta' : 'Fazer login',
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
