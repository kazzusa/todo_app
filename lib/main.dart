import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'screens/add_task_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase.initializeApp failed: $e');
  }

  if (firebaseReady) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous auth failed (non-fatal): $e');
    }
    try {
      await NotificationService.init();
      final token = await NotificationService.getFcmToken();
      if (token != null) {
        await FirestoreService().saveFcmToken(token);
      }
    } catch (e) {
      debugPrint('Notification/FCM setup failed (non-fatal): $e');
    }
  }

  runApp(TodoApp(firebaseReady: firebaseReady));
}

class TodoApp extends StatelessWidget {
  final bool firebaseReady;
  const TodoApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _SetupScreen(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ToDo',
        theme: AppTheme.dark,
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _index = 0;

  static const _screens = [HomeScreen(), CalendarScreen()];

  @override
  void initState() {
    super.initState();
    const MethodChannel('com.personal.todo_app/widget')
        .setMethodCallHandler((call) async {
      if (call.method == 'openAddTask') _openAdd();
    });
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withAlpha(180)),
              const SizedBox(height: 24),
              Text(
                'Firebase Setup Required',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Run the following commands, then replace lib/firebase_options.dart:\n\n'
                '1. dart pub global activate flutterfire_cli\n'
                '2. flutterfire configure\n\n'
                'Then rebuild the app.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
