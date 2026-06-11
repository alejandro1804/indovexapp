import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_mantenimiento_provider.dart';
import 'providers/lectura_maquina_provider.dart';
import 'providers/tipo_intervalo_provider.dart';
import 'providers/repuesto_maquina_provider.dart';
import 'providers/audit_log_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cambiar_password_screen.dart';
import 'screens/home/home_screen.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qxrhrvzvzljeavczzytz.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4cmhydnp2emxqZWF2Y3p6eXR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzOTY5NTQsImV4cCI6MjA5NDk3Mjk1NH0.adhBb-VVbkFTwJh-uTd6eUMOVlXwIrHVqSV_EFp3NcM',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlanMantenimientoProvider()),
        ChangeNotifierProvider(create: (_) => LecturaMaquinaProvider()),
        ChangeNotifierProvider(create: (_) => TipoIntervaloProvider()),
        ChangeNotifierProvider(create: (_) => RepuestoMaquinaProvider()),
        ChangeNotifierProvider(create: (_) => AuditLogProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indovex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E79)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await context.read<AuthProvider>().cargarUsuario();
      if (!mounted) return;
      final usuario = context.read<AuthProvider>().usuario;

      final destino = (usuario != null && usuario.primerLogin)
          ? const CambiarPasswordScreen()
          : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}