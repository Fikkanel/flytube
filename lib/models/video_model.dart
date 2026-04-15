class VideoModel {
  final String videoId;
  final String title;
  final String author;
  final String authorId;
  final String thumbnail;
  final int lengthSeconds;

  VideoModel({
    required this.videoId,
    required this.title,
    required this.author,
    required this.authorId,
    required this.thumbnail,
    required this.lengthSeconds,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    String thumb = '';
    if (json['videoThumbnails'] != null && (json['videoThumbnails'] as List).isNotEmpty) {
      thumb = json['videoThumbnails'][0]['url'] ?? '';
    } else if (json['thumbnails'] != null && (json['thumbnails'] as List).isNotEmpty) {
      thumb = json['thumbnails'][0]['url'] ?? '';
    }

    return VideoModel(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      author: json['author'] ?? 'Unknown Artist',
      authorId: json['authorId'] ?? '',
      thumbnail: thumb,
      lengthSeconds: json['lengthSeconds'] ?? 0,
    );
  }
}
