import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'providers/search_provider.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';
import 'services/pip_service.dart';
import 'widgets/mini_video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services before building widget tree
  final audioHandler = await initAudioService() as FlyTubeAudioHandler;
  final pipService = PipService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider(audioHandler, pipService)),
      ],
      child: const FlyTubeApp(),
    ),
  );
}

class FlyTubeApp extends StatefulWidget {
  const FlyTubeApp({super.key});

  @override
  State<FlyTubeApp> createState() => _FlyTubeAppState();
}

class _FlyTubeAppState extends State<FlyTubeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notify PlayerProvider about app lifecycle changes
    // (handles PiP auto-enter and audio fallback)
    final provider = context.read<PlayerProvider>();
    provider.onAppLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlyTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppShell(),
    );
  }
}

/// App shell that wraps the main content with a global overlay
/// for the mini video player.
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // Main app content
        HomeScreen(),
        // Floating mini video player overlay
        MiniVideoPlayer(),
      ],
    );
  }
}
