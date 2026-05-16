import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:run_app/core/theme.dart';
import 'package:run_app/services/supabase_service.dart';
import 'package:run_app/screens/auth_screen.dart';
import 'package:run_app/screens/main_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o gerenciador de variáveis de ambiente (.env)
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('pt_BR', null);
  await SupabaseService.initialize();

  runApp(const RunApp());
}

class RunApp extends StatelessWidget {
  const RunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Run App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Monitorar estado da autenticação
    return SupabaseService.client.auth.currentUser == null
        ? const AuthScreen()
        : const MainScreen();
  }
}
