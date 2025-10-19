import 'package:flutter/material.dart'; // Thêm import này

class Showtime {
  final String id;
  final String cinemaId;
  final String movieId;
  final DateTime date;
  final TimeOfDay time; // Sử dụng TimeOfDay
  final String? room;

  Showtime({
    required this.id,
    required this.cinemaId,
    required this.movieId,
    required this.date,
    required this.time,
    this.room,
  });

  factory Showtime.fromMap(Map<dynamic, dynamic> map) {
    try {
      return Showtime(
        id: (map['id'] ?? '').toString(),
        cinemaId: (map['cinemaId'] ?? '').toString(),
        movieId: (map['movieId'] ?? '').toString(),
        date:
            DateTime.tryParse((map['date'] ?? '').toString()) ??
            DateTime.now(), // Fallback to current time: 04:08 PM +07, October 18, 2025
        time: _parseTimeOfDay((map['time'] ?? '').toString()),
        room: (map['room'] ?? '').toString(),
      );
    } catch (e) {
      print('Error parsing Showtime from map: $e');
      return Showtime(
        id: '',
        cinemaId: '',
        movieId: '',
        date: DateTime.now(),
        time: const TimeOfDay(hour: 0, minute: 0),
        room: '',
      ); // Fallback object
    }
  }

  static TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
      print('Invalid time format: $timeStr, defaulting to 00:00');
      return const TimeOfDay(hour: 0, minute: 0);
    } catch (e) {
      print('Error parsing time $timeStr: $e');
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }
}
