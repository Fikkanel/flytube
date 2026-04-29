import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/audio_handler.dart';
import '../services/pip_service.dart';

enum PlaybackMode { audio, video }

class PlayerProvider extends ChangeNotifier {
  final FlyTubeAudioHandler audioHandler;
  final PipService pipService;

  String? _lastVideoId;

  PlayerProvider(this.audioHandler, this.pipService) {
    audioHandler.mediaItem.listen((item) {
      if (item != null && item.id != _lastVideoId) {
        _lastVideoId = item.id;
        _videoStreamUrl = null; // Clear old video URL!

        // Revert to audio mode if track changes via queue skip
        if (_currentMode == PlaybackMode.video) {
          _currentMode = PlaybackMode.audio;
          _showMiniPlayer = false;
          pipService.setShouldEnterPip(false);
          _disposeVideoController();
          audioHandler.play();
        }
      }
      notifyListeners();
    });

    // Listen for PiP state changes
    pipService.onPipChanged.listen((isInPip) {
      _isInPipMode = isInPip;
      if (!isInPip && _currentMode == PlaybackMode.video) {
        // Returned from PiP — ensure video controller is still valid
        notifyListeners();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  VideoModel? _currentVideoModel;
  VideoModel? get currentVideo {
    final item = audioHandler.mediaItem.value;
    if (item == null) {
      if (_currentVideoModel != null) return _currentVideoModel;
      return null;
    }
    return VideoModel(
      videoId: item.id,
      title: item.title,
      author: item.artist ?? 'Unknown Artist',
      thumbnail: item.artUri?.toString() ?? '',
      lengthSeconds: item.duration?.inSeconds ?? _currentVideoModel?.lengthSeconds ?? 0,
      authorId: '',
    );
  }

  bool _isLoadingStream = false;
  bool get isLoadingStream => _isLoadingStream;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PlaybackMode _currentMode = PlaybackMode.audio;
  PlaybackMode get currentMode => _currentMode;

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  bool _isVideoReady = false;
  bool get isVideoReady => _isVideoReady;

  bool _isSwitchingMode = false;
  bool get isSwitchingMode => _isSwitchingMode;

  bool _videoFinished = false;

  bool _showMiniPlayer = false;
  bool get showMiniPlayer => _showMiniPlayer && _currentMode == PlaybackMode.video && _videoController != null;

  bool _isInPipMode = false;
  bool get isInPipMode => _isInPipMode;

  String? _videoStreamUrl;

  // ---------------------------------------------------------------------------
  // Play Video (Audio Mode - Default)
  // ---------------------------------------------------------------------------

  Future<void> playVideo(VideoModel video) async {
    _isLoadingStream = true;
    _errorMessage = null;
    _currentVideoModel = video;
    _currentMode = PlaybackMode.audio;
    _showMiniPlayer = false;
    _videoStreamUrl = null;
    _lastVideoId = video.videoId;
    await _disposeVideoController();
    notifyListeners();

    try {
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.author,
        artUri: Uri.parse(video.thumbnail),
      );

      bool success = await audioHandler.loadVideo(mediaItem, '');
      
      if (!success) {
        debugPrint("Percobaan pertama gagal, mencoba ulang...");
        await Future.delayed(const Duration(milliseconds: 500));
        success = await audioHandler.loadVideo(mediaItem, '');
      }

      if (!success) {
        _errorMessage = 'Gagal memutar lagu ini. Silakan coba lagi atau pilih lagu lain.';
      }

      // Update PiP flag
      await pipService.setShouldEnterPip(false);
    } catch (e) {
      _errorMessage = 'Koneksi gagal atau terjadi kesalahan pemutaran.';
      debugPrint("Error loading stream: $e");
    } finally {
      _isLoadingStream = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Switch Mode: Audio ↔ Video
  // ---------------------------------------------------------------------------

  Future<void> switchToVideo() async {
    if (_currentMode == PlaybackMode.video) return;
    final video = currentVideo;
    if (video == null) return;

    _isSwitchingMode = true;
    notifyListeners();

    try {
      // 1. Get current audio position
      final currentPos = audioHandler.currentPosition;

      // 2. Extract muxed video stream URL
      _videoStreamUrl ??= await audioHandler.getVideoStreamUrl(video.videoId);
      
      // Abort if track changed during await
      if (_lastVideoId != video.videoId) return;

      if (_videoStreamUrl == null) {
        debugPrint('Gagal memuat video. Stream video tidak tersedia.');
        _isSwitchingMode = false;
        notifyListeners();
        return;
      }

      // 3. Initialize video player
      await _disposeVideoController();
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_videoStreamUrl!),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        },
      );

      await _videoController!.initialize();
      
      // Abort if track changed during await
      if (_lastVideoId != video.videoId) {
        await _disposeVideoController();
        return;
      }

      _isVideoReady = true;

      // 4. Sync position & switch
      await _videoController!.seekTo(currentPos);
      await audioHandler.pause();
      await _videoController!.play();

      _currentMode = PlaybackMode.video;

      // Enable auto-PiP when in video mode
      await pipService.setShouldEnterPip(true);

      // Listen for video completion
      _videoController!.addListener(_onVideoControllerUpdate);
    } catch (e) {
      debugPrint("Switch to video failed: $e");
      // Don't set global _errorMessage so we don't break the audio player UI
      _currentMode = PlaybackMode.audio;
      // Ensure audio keeps playing
      audioHandler.play();
    } finally {
      _isSwitchingMode = false;
      notifyListeners();
    }
  }

  Future<void> switchToAudio() async {
    if (_currentMode == PlaybackMode.audio) return;

    _isSwitchingMode = true;
    notifyListeners();

    try {
      // 1. Get current video position
      final currentPos = _videoController?.value.position ?? Duration.zero;

      // 2. Switch to audio
      await _videoController?.pause();
      await audioHandler.seek(currentPos);
      await audioHandler.play();

      _currentMode = PlaybackMode.audio;
      _showMiniPlayer = false;

      // Disable auto-PiP
      await pipService.setShouldEnterPip(false);

      // 3. Dispose video controller
      await _disposeVideoController();
    } catch (e) {
      debugPrint("Switch to audio failed: $e");
      audioHandler.play();
    } finally {
      _isSwitchingMode = false;
      notifyListeners();
    }
  }

  void toggleMode() {
    if (_currentMode == PlaybackMode.audio) {
      switchToVideo();
    } else {
      switchToAudio();
    }
  }

  // ---------------------------------------------------------------------------
  // Mini Player (in-app floating video)
  // ---------------------------------------------------------------------------

  void showMiniVideoPlayer() {
    if (_currentMode == PlaybackMode.video && _videoController != null) {
      _showMiniPlayer = true;
      notifyListeners();
    }
  }

  void hideMiniVideoPlayer() {
    _showMiniPlayer = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // App Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> onAppLifecycleChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // App going to background
      if (_currentMode == PlaybackMode.video) {
        final pipSupported = await pipService.isPipSupported();
        if (pipSupported) {
          // PiP will be handled by onUserLeaveHint in native code
          debugPrint("App paused - PiP will be handled natively");
        } else {
          // No PiP support — fallback to audio mode
          debugPrint("No PiP support - switching to audio mode");
          await switchToAudio();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // App back to foreground
      if (_isInPipMode) {
        _isInPipMode = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Video Player Controls
  // ---------------------------------------------------------------------------

  Future<void> videoPlay() async {
    await _videoController?.play();
    notifyListeners();
  }

  Future<void> videoPause() async {
    await _videoController?.pause();
    notifyListeners();
  }

  Future<void> videoSeek(Duration position) async {
    await _videoController?.seekTo(position);
    notifyListeners();
  }

  bool get isVideoPlaying => _videoController?.value.isPlaying ?? false;

  Duration get videoPosition => _videoController?.value.position ?? Duration.zero;

  Duration get videoDuration => _videoController?.value.duration ?? Duration.zero;

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  Future<void> addToQueue(VideoModel video) async {
    final mediaItem = MediaItem(
      id: video.videoId,
      title: video.title,
      artist: video.author,
      artUri: Uri.parse(video.thumbnail),
    );
    await audioHandler.addQueueItem(mediaItem);
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  Stream<Duration> get positionStream => AudioService.position;
  Stream<PlaybackState> get playbackStateStream => audioHandler.playbackState;

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onVideoControllerUpdate() {
    if (_videoController == null) return;

    // Auto-play next track if video is finished
    if (_videoController!.value.isInitialized &&
        _videoController!.value.duration > Duration.zero &&
        _videoController!.value.position >= _videoController!.value.duration) {
      if (!_videoFinished) {
        _videoFinished = true;
        audioHandler.skipToNext();
      }
    } else {
      _videoFinished = false;
    }

    // Notify UI about position/state changes
    notifyListeners();
  }

  Future<void> _disposeVideoController() async {
    _videoController?.removeListener(_onVideoControllerUpdate);
    await _videoController?.dispose();
    _videoController = null;
    _isVideoReady = false;
  }

  @override
  void dispose() {
    _disposeVideoController();
    pipService.dispose();
    super.dispose();
  }
}
