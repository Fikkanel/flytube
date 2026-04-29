import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => FlyTubeAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'id.fikkan.flytube.channel.audio',
      androidNotificationChannelName: 'FlyTube Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class FlyTubeAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  static final _yt = YoutubeExplode();
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Piped API instances as fallback stream extractors
  static const _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.in.projectsegfau.lt',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.syncpundit.io',
  ];

  /// Invidious API instances as secondary fallback
  static const _invidiousInstances = [
    'https://vid.puffyan.us',
    'https://invidious.jing.rocks',
    'https://invidious.nerdvpn.de',
    'https://iv.ggtyler.dev',
  ];

  FlyTubeAudioHandler() {
    _notifyAudioHandlerAboutPlaybackEvents();

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await loadVideo(queue.value[index], '');
  }

  @override
  Future<void> skipToNext() async {
    final currentItem = mediaItem.value;
    if (currentItem == null) return;
    
    final currentIndex = queue.value.indexWhere((item) => item.id == currentItem.id);
    if (currentIndex == -1 || currentIndex >= queue.value.length - 1) {
      if (queue.value.isNotEmpty) {
         await loadVideo(queue.value.first, '');
      }
      return;
    }
    await loadVideo(queue.value[currentIndex + 1], '');
  }

  @override
  Future<void> skipToPrevious() async {
    final currentItem = mediaItem.value;
    if (currentItem == null) return;

    final currentIndex = queue.value.indexWhere((item) => item.id == currentItem.id);
    if (currentIndex <= 0) {
      if (_player.position.inSeconds > 3) {
        await seek(Duration.zero);
      } else if (queue.value.isNotEmpty) {
        await loadVideo(queue.value.last, '');
      }
      return;
    }
    await loadVideo(queue.value[currentIndex - 1], '');
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
      playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
      switch (repeatMode) {
        case AudioServiceRepeatMode.all:
        case AudioServiceRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
        default:
          await _player.setLoopMode(LoopMode.off);
          break;
      }
  }

  // =========================================================================
  // FAST PARALLEL STREAM EXTRACTION
  // =========================================================================

  /// Load and play a video. Uses parallel extraction for ~2-3s loading.
  Future<bool> loadVideo(MediaItem item, String streamUrl) async {
    await _player.stop();
    
    if (!queue.value.any((q) => q.id == item.id)) {
       addQueueItem(item);
    }
    mediaItem.add(item);
    
    try {
      // Race all extraction methods in parallel — first success wins
      final url = await _getStreamUrlFast(item.id);
      
      if (url == null) {
        throw Exception("Semua metode ekstraksi gagal.");
      }
      
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        }
      ));
      
      play();
      return true;
    } catch (e) {
      debugPrint("Gagal memutar video: $e");
      return false; 
    }
  }

  /// Races all extraction sources in parallel — returns first successful URL.
  Future<String?> _getStreamUrlFast(String videoId) async {
    final completer = Completer<String?>();
    int pending = 0;

    void onResult(String? url) {
      if (url != null && !completer.isCompleted) {
        completer.complete(url);
      } else {
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    // Launch youtube_explode clients in parallel
    final ytClients = [
      [YoutubeApiClient.ios],
      [YoutubeApiClient.tv],
      [YoutubeApiClient.safari],
      [YoutubeApiClient.androidVr],
    ];

    for (final clients in ytClients) {
      pending++;
      _extractViaYtExplode(videoId, clients)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    // Launch Piped API instances in parallel as fallback
    for (final instance in _pipedInstances) {
      pending++;
      _extractViaPiped(videoId, instance)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    // Launch Invidious API instances in parallel as secondary fallback
    for (final instance in _invidiousInstances) {
      pending++;
      _extractViaInvidiousAudio(videoId, instance)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    // Overall safety timeout — should resolve much faster via the race
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }

  /// Extract audio stream URL via youtube_explode with a specific client.
  Future<String?> _extractViaYtExplode(
      String videoId, List<YoutubeApiClient> clients) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: clients)
          .timeout(const Duration(seconds: 6));

      if (manifest.audioOnly.isEmpty) return null;

      // Prefer mp4/m4a for compatibility, pick reasonable bitrate
      final sorted = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      final stream = sorted.firstWhere(
        (s) =>
            s.codec.mimeType.contains('mp4') ||
            s.codec.mimeType.contains('m4a'),
        orElse: () => sorted.first,
      );

      return stream.url.toString();
    } catch (e) {
      debugPrint("YT Explode [$clients] gagal: $e");
      return null;
    }
  }

  /// Extract audio stream URL via Piped API instance.
  Future<String?> _extractViaPiped(String videoId, String instance) async {
    try {
      final response = await _dio.get('$instance/streams/$videoId');
      if (response.statusCode == 200 && response.data != null) {
        final audioStreams = response.data['audioStreams'] as List?;
        if (audioStreams != null && audioStreams.isNotEmpty) {
          // Sort by bitrate descending, pick a good quality stream
          audioStreams.sort(
              (a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
          // Pick medium quality for faster buffering
          final idx = audioStreams.length > 2 ? 1 : 0;
          final url = audioStreams[idx]['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (e) {
      debugPrint("Piped [$instance] gagal: $e");
    }
    return null;
  }

  /// Extract audio stream URL via Invidious API instance.
  Future<String?> _extractViaInvidiousAudio(String videoId, String instance) async {
    try {
      final response = await _dio.get('$instance/api/v1/videos/$videoId');
      if (response.statusCode == 200 && response.data != null) {
        final formats = response.data['adaptiveFormats'] as List?;
        if (formats != null) {
          final audioStreams = formats.where((f) => f['type']?.toString().contains('audio') == true).toList();
          if (audioStreams.isNotEmpty) {
            audioStreams.sort((a, b) => (int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0)
                .compareTo(int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0));
            return audioStreams.first['url'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint("Invidious Audio [$instance] gagal: $e");
    }
    return null;
  }

  // =========================================================================
  // VIDEO (MUXED) STREAM EXTRACTION
  // =========================================================================

  /// Get a muxed (video+audio) stream URL for video playback mode.
  /// Uses parallel extraction similar to audio — first success wins.
  Future<String?> getVideoStreamUrl(String videoId) async {
    final completer = Completer<String?>();
    int pending = 0;

    void onResult(String? url) {
      if (url != null && !completer.isCompleted) {
        completer.complete(url);
      } else {
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    // youtube_explode muxed streams in parallel
    final ytClients = [
      [YoutubeApiClient.ios],
      [YoutubeApiClient.tv],
      [YoutubeApiClient.safari],
      [YoutubeApiClient.androidVr],
    ];

    for (final clients in ytClients) {
      pending++;
      _extractMuxedViaYtExplode(videoId, clients)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    // Piped video streams in parallel
    for (final instance in _pipedInstances) {
      pending++;
      _extractVideoViaPiped(videoId, instance)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    // Invidious video streams in parallel
    for (final instance in _invidiousInstances) {
      pending++;
      _extractViaInvidiousVideo(videoId, instance)
          .then(onResult)
          .catchError((_) => onResult(null));
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }

  /// Extract muxed (video+audio) stream via youtube_explode.
  Future<String?> _extractMuxedViaYtExplode(
      String videoId, List<YoutubeApiClient> clients) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: clients)
          .timeout(const Duration(seconds: 6));

      if (manifest.muxed.isEmpty) return null;

      // Prefer 720p, fallback to highest available
      final sorted = manifest.muxed.toList()
        ..sort((a, b) =>
            b.videoResolution.height.compareTo(a.videoResolution.height));

      final stream = sorted.firstWhere(
        (s) => s.videoResolution.height <= 720,
        orElse: () => sorted.last,
      );

      return stream.url.toString();
    } catch (e) {
      debugPrint("YT Muxed [$clients] gagal: $e");
      return null;
    }
  }

  /// Extract video stream via Piped API.
  Future<String?> _extractVideoViaPiped(String videoId, String instance) async {
    try {
      final response = await _dio.get('$instance/streams/$videoId');
      if (response.statusCode == 200 && response.data != null) {
        final videoStreams = response.data['videoStreams'] as List?;
        if (videoStreams != null && videoStreams.isNotEmpty) {
          // Filter for streams with audio (non-DASH, videoOnly=false)
          final muxed = videoStreams
              .where((s) => s['videoOnly'] == false)
              .toList();
          if (muxed.isEmpty) return null;

          // Sort by quality, prefer 720p
          muxed.sort(
              (a, b) => (b['quality']?.toString().replaceAll('p', '') ?? '0')
                  .compareTo(a['quality']?.toString().replaceAll('p', '') ?? '0'));

          // Find 720p or closest
          final stream = muxed.firstWhere(
            (s) => s['quality']?.toString().contains('720') == true,
            orElse: () => muxed.first,
          );
          final url = stream['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (e) {
      debugPrint("Piped Video [$instance] gagal: $e");
    }
    return null;
  }

  /// Extract muxed video stream URL via Invidious API instance.
  Future<String?> _extractViaInvidiousVideo(String videoId, String instance) async {
    try {
      final response = await _dio.get('$instance/api/v1/videos/$videoId');
      if (response.statusCode == 200 && response.data != null) {
        final formats = response.data['formatStreams'] as List?;
        if (formats != null) {
          final videoStreams = formats.where((f) => f['type']?.toString().contains('video/mp4') == true).toList();
          if (videoStreams.isNotEmpty) {
            videoStreams.sort((a, b) {
              int resA = int.tryParse(a['resolution']?.toString().replaceAll('p', '') ?? '0') ?? 0;
              int resB = int.tryParse(b['resolution']?.toString().replaceAll('p', '') ?? '0') ?? 0;
              return resB.compareTo(resA);
            });
            // Try to find 720p or fallback
            final stream = videoStreams.firstWhere(
              (s) => s['resolution']?.toString().contains('720') == true,
              orElse: () => videoStreams.first,
            );
            return stream['url'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint("Invidious Video [$instance] gagal: $e");
    }
    return null;
  }

  /// Current playback position (exposed for mode switching sync).
  Duration get currentPosition => _player.position;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}
