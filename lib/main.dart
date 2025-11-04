import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:attempt2/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load env variables
  await dotenv.load(fileName: "assets/.env");

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
    // Continue anyway as we have fallback to dummy auth
  }

  // Run the app
  runApp(const App());
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _initialized = false;
  bool _error = false;
  String _errorMessage = '';

  // Define an initialization function
  Future<void> _initializeApp() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    // Show error UI if initialization failed
    if (_error) {
      return MaterialApp(
        title: 'Diet & Fitness App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Error: $_errorMessage',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = false;
                      _errorMessage = '';
                    });
                    _initializeApp();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show a loading screen while initializing
    if (!_initialized) {
      return MaterialApp(
        title: 'Diet & Fitness App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing App...'),
              ],
            ),
          ),
        ),
      );
    }

    // If initialized, show the actual app
    return const App();
  }
}
