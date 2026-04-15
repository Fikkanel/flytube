import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
         // Loop back or stop. We'll loop to the beginning if they hit next at the end.
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
      // If at start, either restart song or go to end
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

  Future<bool> loadVideo(MediaItem item, String streamUrl) async {
    // AUDIO OVERLAP BUG FIX: Directly stop current playback
    await _player.stop();
    
    // Add to queue if not present
    if (!queue.value.any((q) => q.id == item.id)) {
       addQueueItem(item);
    }
    
    mediaItem.add(item);
    
    try {
      final clientsToTry = [
        [YoutubeApiClient.tv],
        [YoutubeApiClient.ios],
        [YoutubeApiClient.safari],
        [YoutubeApiClient.androidVr],
      ];
      
      StreamManifest? manifest;
      for (final clients in clientsToTry) {
        try {
          manifest = await _yt.videos.streamsClient.getManifest(item.id, ytClients: clients);
          if (manifest.audioOnly.isNotEmpty) {
            break; // Berhasil mendeteksi aliran suara!
          }
        } catch (e) {
          debugPrint("Client $clients gagal: $e");
          continue; // Coba client berikutnya
        }
      }

      if (manifest == null || manifest.audioOnly.isEmpty) {
         throw Exception("Semua jalur ekstraksi YouTube terblokir.");
      }
      
      final streamInfo = manifest.audioOnly.firstWhere(
        (s) => s.codec.mimeType.contains('mp4') || s.codec.mimeType.contains('m4a'),
        orElse: () => manifest!.audioOnly.first
      );
      
      await _player.setAudioSource(AudioSource.uri(
        streamInfo.url,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        }
      ));
      
      play();
      return true; // Berhasil dimuat murni!
    } catch (e) {
      debugPrint("Gagal memutar video setelah semua bypass internal dicoba: $e");
      return false; 
    }
  }

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
