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

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'author': author,
      'authorId': authorId,
      'thumbnail': thumbnail,
      'lengthSeconds': lengthSeconds,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      videoId: map['videoId'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      authorId: map['authorId'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      lengthSeconds: map['lengthSeconds'] ?? 0,
    );
  }
}
