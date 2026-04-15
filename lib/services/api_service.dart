import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_model.dart';

class ApiService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<VideoModel>> searchVideos(String query) async {
    try {
      final videos = await _yt.search.search(query);
      return videos.map((video) {
        return VideoModel(
          videoId: video.id.value,
          title: video.title,
          author: video.author,
          authorId: video.channelId.value,
          thumbnail: video.thumbnails.highResUrl,
          lengthSeconds: video.duration?.inSeconds ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Exception('Terdapat masalah pada koneksi ke Youtube: $e');
    }
  }

  /// Extracts the direct audio stream URL
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // Mendapatkan stream kualitas terbaik untuk audio (biasanya m4a / aac / opus)
      var audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Failed to get stream: $e');
    }
  }
}
