import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_tab_screen.dart';
import 'providers/search_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'services/audio_handler.dart';
import 'services/pip_service.dart';
import 'widgets/mini_video_player.dart';
import 'package:video_player/video_player.dart';

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
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
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
      builder: (context, child) {
        return Consumer<PlayerProvider>(
          builder: (context, provider, _) {
            if (provider.isInPipMode && provider.videoController != null) {
              return Material(
                color: Colors.black,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: provider.videoController!.value.size.width,
                      height: provider.videoController!.value.size.height,
                      child: VideoPlayer(provider.videoController!),
                    ),
                  ),
                ),
              );
            }
            return child!;
          },
        );
      },
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
        MainTabScreen(),
        // Floating mini video player overlay
        MiniVideoPlayer(),
      ],
    );
  }
}
