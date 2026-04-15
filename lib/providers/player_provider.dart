import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/video_model.dart';
import '../services/audio_handler.dart';

class PlayerProvider extends ChangeNotifier {
  final FlyTubeAudioHandler audioHandler;

  PlayerProvider(this.audioHandler) {
    audioHandler.mediaItem.listen((item) {
      notifyListeners();
    });
  }

  VideoModel? get currentVideo {
    final item = audioHandler.mediaItem.value;
    if (item == null) return null;
    return VideoModel(
      videoId: item.id,
      title: item.title,
      author: item.artist ?? 'Unknown Artist',
      thumbnail: item.artUri?.toString() ?? '',
      lengthSeconds: 0,
      authorId: '',
    );
  }
  bool _isLoadingStream = false;
  bool get isLoadingStream => _isLoadingStream;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> playVideo(VideoModel video) async {
    _isLoadingStream = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mediaItem = MediaItem(
        id: video.videoId,
        title: video.title,
        artist: video.author,
        artUri: Uri.parse(video.thumbnail),
      );

      // Stream handling is done autonomously by audioHandler LocalProxy
      final success = await audioHandler.loadVideo(mediaItem, '');
      
      if (!success) {
        _errorMessage = 'Lagu ini diproteksi hak cipta DRM (Video Unavailable). Coba lagu lain.';
      }

    } catch (e) {
      _errorMessage = 'Koneksi gagal atau terjadi kesalahan pemutaran.';
      debugPrint("Error loading stream: $e");
    } finally {
      _isLoadingStream = false;
      notifyListeners();
    }
  }

  Future<void> addToQueue(VideoModel video) async {
    final mediaItem = MediaItem(
      id: video.videoId,
      title: video.title,
      artist: video.author,
      artUri: Uri.parse(video.thumbnail),
    );
    await audioHandler.addQueueItem(mediaItem);
  }

  Stream<Duration> get positionStream => AudioService.position;
  Stream<PlaybackState> get playbackStateStream => audioHandler.playbackState;
}
