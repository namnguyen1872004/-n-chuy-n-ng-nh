import 'package:flutter/material.dart';

class Showtime {
  final TimeOfDay start;
  final TimeOfDay end;
  final int available;
  final int total;
  final String format;
  final String subtitle;

  const Showtime({
    required this.start,
    required this.end,
    required this.available,
    required this.total,
    required this.format,
    required this.subtitle,
  });

  /// Parse from flexible DB representation (Map, String times, or int minutes)
  static Showtime? fromAny(dynamic v) {
    if (v is Map) {
      TimeOfDay? toTOD(dynamic x) {
        if (x is String && x.contains(':')) {
          final p = x.split(':');
          final h = int.tryParse(p[0]) ?? 0;
          final m = int.tryParse(p[1]) ?? 0;
          return TimeOfDay(hour: h, minute: m);
        }
        if (x is int) {
          final h = (x ~/ 60).clamp(0, 23);
          final m = (x % 60).clamp(0, 59);
          return TimeOfDay(hour: h, minute: m);
        }
        return null;
      }

      final st = toTOD(v['start']) ?? const TimeOfDay(hour: 0, minute: 0);
      final en = toTOD(v['end']) ?? const TimeOfDay(hour: 0, minute: 0);
      final avail = (v['available'] is num)
          ? (v['available'] as num).toInt()
          : int.tryParse('${v['available'] ?? 0}') ?? 0;
      final tot = (v['total'] is num)
          ? (v['total'] as num).toInt()
          : int.tryParse('${v['total'] ?? 0}') ?? 0;
      final fmt = (v['format'] ?? '2D').toString();
      final sub = (v['subtitle'] ?? '').toString().isEmpty
          ? 'Phụ đề'
          : v['subtitle'].toString();

      return Showtime(
        start: st,
        end: en,
        available: avail,
        total: tot,
        format: fmt,
        subtitle: sub,
      );
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'start':
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
    'end':
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
    'available': available,
    'total': total,
    'format': format,
    'subtitle': subtitle,
  };
}
