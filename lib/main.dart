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
import 'providers/legal_provider.dart';
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
        ChangeNotifierProvider(create: (_) => LegalProvider()),
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
      title: 'IndovexApp',
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

  // Guarda un link entrante que aún no se pudo procesar (ej: app sin sesión,
  // o home todavía no montado).
  Uri? _pendingDeepLink;

  // Indica que el home ya está montado y se pueden procesar deep links.
  bool _listoParaDeepLinks = false;

  // Evita que el flujo normal de _checkSession redirija cuando estamos
  // en medio de un recovery de contraseña.
  bool _enRecovery = false;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
    _initDeepLinks();
    _checkSession();
  }

  // Escucha los cambios de estado de auth. El evento passwordRecovery se
  // dispara cuando el usuario vuelve desde el link del mail de "olvidé
  // mi contraseña" (Supabase procesa el token automáticamente).
  void _initAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _enRecovery = true;
        // Cargar el usuario (la sesión de recovery ya está activa) y abrir
        // la pantalla para definir la nueva contraseña.
        _abrirPantallaNuevaPassword();
      }
    });
  }

  Future<void> _abrirPantallaNuevaPassword() async {
    // Aseguramos que el provider tenga el usuario cargado para que, tras
    // guardar la nueva contraseña, HomeScreen tenga los datos.
    try {
      await context.read<AuthProvider>().cargarUsuario();
    } catch (_) {
      // Si falla la carga seguimos igual: la pantalla solo necesita la sesión.
    }
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const CambiarPasswordScreen(esRecovery: true),
      ),
      (route) => false,
    );
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // App abierta en background: escucha links entrantes
    _appLinks.uriLinkStream.listen((uri) {
      _procesarOGuardar(uri);
    });

    // App estaba cerrada: chequea si se abrió con un link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _procesarOGuardar(uri);
    });
  }

  // Decide si procesar el link ahora o guardarlo para después.
  void _procesarOGuardar(Uri uri) {
    if (_listoParaDeepLinks &&
        Supabase.instance.client.auth.currentSession != null) {
      _handleDeepLink(uri);
    } else {
      _pendingDeepLink = uri;
    }
  }

  // Procesa un link guardado, si existe y hay sesión.
  void _procesarPendiente() {
    final uri = _pendingDeepLink;
    if (uri != null &&
        Supabase.instance.client.auth.currentSession != null) {
      _pendingDeepLink = null;
      _handleDeepLink(uri);
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
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
        debugPrint('Deep link: máquina no encontrada ($maquinaId): $e');
      }
    }
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Si estamos en recovery, el listener de auth se encarga de la navegación.
    // No redirigimos a Home/Login para no pisar la pantalla de nueva contraseña.
    if (_enRecovery) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await context.read<AuthProvider>().cargarUsuario();
      if (!mounted) return;

      // Re-chequeo: el listener pudo haber marcado recovery mientras cargábamos.
      if (_enRecovery) return;

      final usuario = context.read<AuthProvider>().usuario;

      final destino = (usuario != null && usuario.primerLogin)
          ? const CambiarPasswordScreen()
          : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );

      // El home ya está montado: ahora sí se pueden procesar deep links.
      // Esperamos un frame para asegurar que la navegación terminó.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listoParaDeepLinks = true;
        _procesarPendiente();
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      // Sin sesión: el deep link (si lo hay) queda guardado en _pendingDeepLink
      // y se procesará cuando el usuario se loguee y vuelva a abrirse el link.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}