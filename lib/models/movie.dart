import 'package:flutter/material.dart';

class Movie {
  // ==== Core fields ====
  final String id;
  final String title;
  final String description;
  final String posterUrl; // Ảnh poster (đã chọn từ nhiều khoá)
  final int duration; // phút
  final String genre;
  final DateTime releaseDate;
  final String director;
  final List<String> actors;
  final double rating; // 0..5
  final String directorImageUrl;
  final List<String> actorsImageUrls;
  final String? trailerUrl;
  final List<String> galleryImages;

  /// Liên kết rạp (tuỳ chọn, giữ nguyên kiểu linh hoạt)
  final Map<String, dynamic>? cinemas; // ví dụ: { "1": true, "2": true }

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

  // -----------------------------
  // Helpers parse nho nhỏ
  // -----------------------------

  /// Lấy URL hình theo nhiều khoá phổ biến
  static String _pickPoster(Map<dynamic, dynamic> m) {
    const keys = ['posterUrl', 'posterURL', 'image', 'img'];
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  /// Chuyển động về List<String>, chịu được List/Map/null
  static List<String> _toStrList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is Map) return v.values.map((e) => e.toString()).toList();
    return const [];
  }

  /// Parse DateTime: nhận ISO hoặc epoch (ms/s)
  static DateTime _parseDate(dynamic v) {
    if (v is int) {
      // nếu quá 10^12 coi là millis
      return DateTime.fromMillisecondsSinceEpoch(
        v > 1000000000000 ? v : v * 1000,
      );
    }
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Rating clamp 0..5
  static double _clampRating(dynamic v) {
    double r;
    if (v is num)
      r = v.toDouble();
    else
      r = double.tryParse(v?.toString() ?? '') ?? 0.0;
    if (r < 0) r = 0;
    if (r > 5) r = 5;
    return r;
  }

  /// Duration về int phút
  static int _parseDuration(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  // -----------------------------
  // fromMap / fromJson (giống nhau)
  // -----------------------------
  factory Movie.fromMap(Map<dynamic, dynamic> map) {
    final m = map.map((k, v) => MapEntry(k.toString(), v));
    return Movie(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      posterUrl: _pickPoster(m),
      duration: _parseDuration(m['duration']),
      genre: (m['genre'] ?? '').toString(),
      releaseDate: _parseDate(m['releaseDate']),
      director: (m['director'] ?? '').toString(),
      actors: _toStrList(m['actors']),
      rating: _clampRating(m['rating']),
      directorImageUrl: (m['directorImageUrl'] ?? '').toString(),
      actorsImageUrls: _toStrList(m['actorsImageUrls']),
      trailerUrl: (() {
        final t = m['trailerUrl']?.toString() ?? '';
        return t.isNotEmpty ? t : null;
      })(),
      galleryImages: _toStrList(m['galleryImages']),
      cinemas: (m['cinemas'] is Map)
          ? Map<String, dynamic>.from(m['cinemas'])
          : null,
    );
  }

  factory Movie.fromJson(Map<String, dynamic> json) => Movie.fromMap(json);

  // -----------------------------
  // toMap / toJson
  // -----------------------------
  Map<String, dynamic> toMap() => {
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

  Map<String, dynamic> toJson() => toMap();

  // -----------------------------
  // copyWith tiện chỉnh trên UI
  // -----------------------------
  Movie copyWith({
    String? id,
    String? title,
    String? description,
    String? posterUrl,
    int? duration,
    String? genre,
    DateTime? releaseDate,
    String? director,
    List<String>? actors,
    double? rating,
    String? directorImageUrl,
    List<String>? actorsImageUrls,
    String? trailerUrl,
    List<String>? galleryImages,
    Map<String, dynamic>? cinemas,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      director: director ?? this.director,
      actors: actors ?? this.actors,
      rating: rating ?? this.rating,
      directorImageUrl: directorImageUrl ?? this.directorImageUrl,
      actorsImageUrls: actorsImageUrls ?? this.actorsImageUrls,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      cinemas: cinemas ?? this.cinemas,
    );
  }
}
