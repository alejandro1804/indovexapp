import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_mantenimiento_provider.dart';
import 'providers/lectura_maquina_provider.dart';
import 'providers/tipo_intervalo_provider.dart';
import 'providers/repuesto_maquina_provider.dart';
import 'providers/audit_log_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cambiar_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/maquinas/maquina_detail_screen.dart';
import 'models/maquina.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qxrhrvzvzljeavczzytz.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4cmhydnp2emxqZWF2Y3p6eXR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzOTY5NTQsImV4cCI6MjA5NDk3Mjk1NH0.adhBb-VVbkFTwJh-uTd6eUMOVlXwIrHVqSV_EFp3NcM',
);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey,
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
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkSession();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // App abierta en background: escucha links entrantes
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // App estaba cerrada: chequea si se abrió con un link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Espera a que haya sesión activa antes de navegar
    if (Supabase.instance.client.auth.currentSession == null) return;

    // https://app.indovexapp.com/maquina/{id}
    if (uri.scheme == 'https' &&
        uri.host == 'app.indovexapp.com' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments[0] == 'maquina') {
      final maquinaId =
          uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (maquinaId == null) return;

      try {
        final data = await Supabase.instance.client
            .from('maquinas')
            .select()
            .eq('id', maquinaId)
            .single();

        final maquina = Maquina.fromMap(data);

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MaquinaDetailScreen(maquina: maquina),
          ),
        );
      } catch (e) {
        // Máquina no encontrada o sin permiso — no navegar
        debugPrint('Deep link: máquina no encontrada ($maquinaId): $e');
      }
    }
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