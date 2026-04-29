import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import '../models/video_model.dart';

class ApiService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

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

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {
          'client': 'youtube',
          'ds': 'yt',
          'q': query,
        },
      );

      if (response.statusCode == 200) {
        // Response format is typically: window.google.ac.h(["query",[["suggestion1",0],["suggestion2",0]],...])
        // Or a cleaner JSON if headers are set, but usually it's a JS callback string.
        // We can parse it manually.
        final String data = response.data.toString();
        final List<String> suggestions = [];
        
        final regExp = RegExp(r'\["([^"]+)",');
        final matches = regExp.allMatches(data);
        
        for (var i = 1; i < matches.length; i++) { // Skip the first match (the query itself)
          suggestions.add(matches.elementAt(i).group(1)!);
        }
        return suggestions;
      }
      return [];
    } catch (e) {
      return [];
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
