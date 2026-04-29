import 'dart:convert';
import 'video_model.dart';

class PlaylistModel {
  final String id;
  final String name;
  final List<VideoModel> videos;

  PlaylistModel({
    required this.id,
    required this.name,
    this.videos = const [],
  });

  PlaylistModel copyWith({
    String? id,
    String? name,
    List<VideoModel>? videos,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      videos: videos ?? this.videos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'videos': videos.map((x) => x.toMap()).toList(),
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      videos: List<VideoModel>.from(
        (map['videos'] as List? ?? []).map<VideoModel>(
          (x) => VideoModel.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) =>
      PlaylistModel.fromMap(json.decode(source));
}
