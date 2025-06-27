import 'dart:async';
import 'dart:io';
// import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:project/provider/auth_provider.dart';
import 'package:project/provider/clearance_state_provider.dart';
import 'package:project/screens/forgot_password_screen.dart';
import 'package:project/screens/register_screen.dart';
import 'package:project/screens/reset_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await Hive.initFlutter();
    } else {
      Hive.initFlutter();
    }
    await Hive.openBox('clearance_data');
  } catch (e) {
    print('Error initializing Hive: $e');
  }
  // const bool isProduction = bool.fromEnvironment('dart.vm.product');
  runApp(//isProduction?
      const ClearanceApp());
  // : DevicePreview(builder: (context) => const ClearanceApp()));
}

class ClearanceApp extends StatefulWidget {
  const ClearanceApp({super.key});

  @override
  _ClearanceAppState createState() => _ClearanceAppState();
}

class _ClearanceAppState extends State<ClearanceApp> {
  final AppLinks _appLinks = AppLinks();
  Uri? _initialUri;
  late StreamSubscription<Uri> _linkSubscription;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeProviders();
    _initDeepLinks();
  }

  Future<void> _initializeProviders() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clearanceProvider =
        Provider.of<ClearanceStateProvider>(context, listen: false);
    try {
      print('Initializing AuthProvider');
      await authProvider.init();
      print('AuthProvider initialized, user: ${authProvider.user?.username}');
      if (authProvider.user != null && authProvider.accessToken != null) {
        print('Initializing ClearanceStateProvider');
        await clearanceProvider.initialize(
            authProvider.user!.username, authProvider.accessToken!);
      }
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      _initialUri = await _appLinks.getInitialLink();
      if (_initialUri != null && mounted) {
        _handleUri(_initialUri!);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && mounted) {
        _handleUri(uri);
      }
    }, onError: (err) {
      print('Error listening to links: $err');
    });
  }

  void _handleUri(Uri uri) {
    print('Handling URI: $uri');
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty && pathSegments[0] == 'reset-password') {
      if (pathSegments.length >= 3) {
        final uid = pathSegments[1];
        final token = pathSegments[2];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(
            context,
            '/reset-password/:uid/:token',
            arguments: {'uid': uid, 'token': token},
          );
        });
      } else {
        print('Invalid reset-password URI: $uri');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid password reset link')),
          );
        }
      }
    } else if (pathSegments.isNotEmpty && pathSegments[0] == 'return') {
      final returnTo = uri.queryParameters['to'] ?? '/';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, returnTo);
      });
    } else {
      print('Unhandled URI: $uri');
    }
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) =>
                AuthProvider()), // Provide the initialized AuthProvider
        ChangeNotifierProvider(create: (_) => ClearanceStateProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Clearance App',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: Colors.white,
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Colors.green,
            contentTextStyle: TextStyle(color: Colors.black),
          ),
        ),
        home: FutureBuilder<void>(
          future: _initializationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                if (authProvider.user != null) {
                  return const DashboardScreen();
                } else {
                  return const LoginScreen();
                }
              },
            );
          },
        ),
        routes: {
          '/register': (_) => const RegisterScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/reset-password/:uid/:token': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, String>?;
            return ResetPasswordScreen(
              uid: args?['uid'] ?? '',
              token: args?['token'] ?? '',
            );
          },
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}
