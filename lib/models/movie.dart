import 'package:flutter/material.dart';

class Movie {
  final String id; // ID duy nhất của phim
  final String title; // Tên phim
  final String description; // Mô tả phim
  final String posterUrl; // URL hình ảnh poster
  final int duration; // Thời lượng phim (phút)
  final String genre; // Thể loại phim
  final DateTime releaseDate; // Ngày phát hành
  final String director; // Đạo diễn
  final List<String> actors; // Danh sách diễn viên
  final double rating; // Đánh giá sao (1-5)
  final String directorImageUrl; // Ảnh đạo diễn
  final List<String> actorsImageUrls; // Ảnh diễn viên
  final String? trailerUrl; // Trailer
  final List<String> galleryImages; // Ảnh phim

  // Thêm field tùy chọn để liên kết với rạp (nếu cần sau này)
  final Map<String, dynamic>? cinemas; // { "1": true, "2": true }

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.duration,
    required this.genre,
    required this.releaseDate,
    required this.director,
    required this.actors,
    required this.rating,
    required this.directorImageUrl,
    required this.actorsImageUrls,
    this.trailerUrl,
    this.galleryImages = const [],
    this.cinemas,
  });

  /// --- fromMap an toàn ---
  factory Movie.fromMap(Map<dynamic, dynamic> map) {
    // Hàm nhỏ để convert list linh hoạt
    List<String> _safeList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is Map) return v.values.map((e) => e.toString()).toList();
      return [];
    }

    return Movie(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      posterUrl: (map['posterUrl'] ?? '').toString(),

      /// Duration có thể là int, double, hoặc String
      duration: (map['duration'] is num)
          ? (map['duration'] as num).toInt()
          : int.tryParse('${map['duration'] ?? 0}') ?? 0,

      genre: (map['genre'] ?? '').toString(),

      /// Nếu releaseDate không có → dùng DateTime.now()
      releaseDate:
          DateTime.tryParse(map['releaseDate']?.toString() ?? '') ??
          DateTime.now(),

      director: (map['director'] ?? '').toString(),

      /// Actors và ảnh diễn viên an toàn
      actors: _safeList(map['actors']),
      actorsImageUrls: _safeList(map['actorsImageUrls']),
      galleryImages: _safeList(map['galleryImages']),

      rating: (map['rating'] is num)
          ? (map['rating'] as num).toDouble()
          : double.tryParse('${map['rating'] ?? 0}') ?? 0.0,

      directorImageUrl: (map['directorImageUrl'] ?? '').toString(),

      trailerUrl: (map['trailerUrl']?.toString().isNotEmpty ?? false)
          ? map['trailerUrl'].toString()
          : null,

      cinemas: (map['cinemas'] is Map)
          ? Map<String, dynamic>.from(map['cinemas'])
          : null,
    );
  }

  /// --- toMap để lưu lại lên Firebase (nếu cần push/update) ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'duration': duration,
      'genre': genre,
      'releaseDate': releaseDate.toIso8601String(),
      'director': director,
      'actors': actors,
      'rating': rating,
      'directorImageUrl': directorImageUrl,
      'actorsImageUrls': actorsImageUrls,
      'trailerUrl': trailerUrl ?? '',
      'galleryImages': galleryImages,
      if (cinemas != null) 'cinemas': cinemas,
    };
  }
}
