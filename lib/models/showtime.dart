import 'package:flutter/material.dart';

class Showtime {
  final String id;
  final String cinemaId;
  final String movieId;
  final String date; // yyyyMMdd
  final String time; // HH:mm (24h), ví dụ "09:30"
  final String room;
  final int price;

  Showtime({
    required this.id,
    required this.cinemaId,
    required this.movieId,
    required this.date,
    required this.time,
    required this.room,
    required this.price,
  });

  // ============== Helpers thời gian ==============

  static int minutesOf(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return h * 60 + m;
  }

  static bool isPastForDate(DateTime date, String hhmm, DateTime now) {
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday) return false;
    return minutesOf(hhmm) <= now.hour * 60 + now.minute;
  }

  /// Nhãn khung giờ (0 giữ “Tất cả” để tương thích cũ; UI sẽ bỏ qua index 0).
  static const List<String> slotLabels = <String>[
    'Tất cả',
    '09:00–12:00',
    '12:00–15:00',
    '15:00–18:00',
    '18:00–21:00',
    '21:00–24:00',
  ];

  /// Kiểm tra 1 giờ có thuộc slotIndex hay không
  /// (0 = mọi slot; 1..n = khung cụ thể). UI mới sẽ không truyền 0 nữa.
  static bool inSlot(String hhmm, int slotIndex) {
    if (slotIndex == 0) return true;
    final mins = minutesOf(hhmm);
    final def = _slotByIndex(slotIndex);
    if (def.index == 0) return true;
    return mins >= def.startMinute && mins < def.endMinute;
  }

  static _SlotDef _slotByIndex(int i) {
    switch (i) {
      case 1:
        return const _SlotDef(
          index: 1,
          label: '09:00–12:00',
          startMinute: 9 * 60,
          endMinute: 12 * 60,
        );
      case 2:
        return const _SlotDef(
          index: 2,
          label: '12:00–15:00',
          startMinute: 12 * 60,
          endMinute: 15 * 60,
        );
      case 3:
        return const _SlotDef(
          index: 3,
          label: '15:00–18:00',
          startMinute: 15 * 60,
          endMinute: 18 * 60,
        );
      case 4:
        return const _SlotDef(
          index: 4,
          label: '18:00–21:00',
          startMinute: 18 * 60,
          endMinute: 21 * 60,
        );
      case 5:
        return const _SlotDef(
          index: 5,
          label: '21:00–24:00',
          startMinute: 21 * 60,
          endMinute: 24 * 60,
        );
      default:
        return const _SlotDef.empty();
    }
  }
}

class _SlotDef {
  final int index;
  final String label;
  final int startMinute;
  final int endMinute;
  const _SlotDef({
    required this.index,
    required this.label,
    required this.startMinute,
    required this.endMinute,
  });
  const _SlotDef.empty()
    : index = 0,
      label = '',
      startMinute = 0,
      endMinute = 0;
}
