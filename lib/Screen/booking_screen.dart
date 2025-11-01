// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/movie.dart';
import '../models/cinema_model.dart';
import 'seat_selection_screen.dart';

class BookingScreen extends StatefulWidget {
  final Movie movie;
  const BookingScreen({super.key, required this.movie});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  DateTime now = DateTime.now();
  Timer? _nowTimer;

  int selectedDayIndex = 0;
  int selectedCinemaIndex = 0;
  int selectedTimeIndex = 0;

  List<DateTime> availableDates = [];
  List<Cinema> cinemas = [];
  bool isLoading = true;

  static const List<List<int>> _fallbackSlots = [
    [9, 0, 11, 0],
    [13, 0, 15, 0],
    [17, 0, 19, 0],
    [20, 0, 22, 0],
  ];

  @override
  void initState() {
    super.initState();
    _rebuildAvailableDates();
    _fetchCinemas();
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => now = DateTime.now());
    });
  }

  /// ✅ Lấy dữ liệu từ Firebase (tự nhận Map/List)
  Future<void> _fetchCinemas() async {
    try {
      final snapshot = await _database.child('cinemas').get();
      if (!snapshot.exists) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy dữ liệu rạp trên Firebase'),
          ),
        );
        return;
      }

      final raw = snapshot.value;
      final List<Cinema> loaded = [];

      if (raw is Map) {
        // ✅ Dữ liệu kiểu Map {"1": {...}, "2": {...}}
        raw.forEach((_, value) {
          if (value is Map) {
            loaded.add(Cinema.fromMap(Map<String, dynamic>.from(value)));
          }
        });
      } else if (raw is List) {
        // ✅ Dữ liệu kiểu List [{...}, {...}]
        for (final item in raw) {
          if (item == null) continue;
          if (item is Map) {
            loaded.add(Cinema.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      } else {
        throw Exception('Dữ liệu không đúng định dạng.');
      }

      setState(() {
        cinemas = loaded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
    }
  }

  /// ✅ Xử lý openHours cả 2 dạng: "09:00-11:00, 14:00-16:00" hoặc "09:00 - 23:00"
  List<List<int>> _parseSlots(String openHours) {
    try {
      if (openHours.contains(',')) {
        // Nhiều khung giờ, ví dụ "09:00-11:00, 14:00-16:00"
        return openHours.split(',').map((part) {
          final range = part.trim().split('-');
          final start = range[0].trim().split(':').map(int.parse).toList();
          final end = range[1].trim().split(':').map(int.parse).toList();
          return [start[0], start[1], end[0], end[1]];
        }).toList();
      }

      if (openHours.contains('-')) {
        // Một khoảng dài, ví dụ "09:00 - 23:00" → chia nhỏ 4 suất
        final range = openHours.split('-');
        final start = range[0].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final end = range[1].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final startHour = int.tryParse(start[0]) ?? 9;
        final endHour = int.tryParse(end[0]) ?? 23;
        final diff = endHour - startHour;
        final step = diff ~/ 4;

        final slots = <List<int>>[];
        for (int i = 0; i < 4; i++) {
          final sh = startHour + i * step;
          final eh = (i == 3) ? endHour : sh + step;
          slots.add([sh, 0, eh, 0]);
        }
        return slots;
      }

      return _fallbackSlots;
    } catch (_) {
      return _fallbackSlots;
    }
  }

  void _rebuildAvailableDates() {
    final base = DateTime(now.year, now.month, now.day);
    availableDates = List.generate(6, (i) => base.add(Duration(days: i)));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) {
    const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    const months = [
      'Th1',
      'Th2',
      'Th3',
      'Th4',
      'Th5',
      'Th6',
      'Th7',
      'Th8',
      'Th9',
      'Th10',
      'Th11',
      'Th12',
    ];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = availableDates[selectedDayIndex];
    final selectedCinema = cinemas.isNotEmpty
        ? cinemas[selectedCinemaIndex]
        : null;

    final rawSlots = selectedCinema == null
        ? _fallbackSlots
        : _parseSlots(selectedCinema.openHours);

    final times = rawSlots
        .map(
          (s) => {
            'start': TimeOfDay(hour: s[0], minute: s[1]),
            'end': TimeOfDay(hour: s[2], minute: s[3]),
          },
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            )
          : cinemas.isEmpty
          ? const Center(
              child: Text(
                'Không có rạp khả dụng!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMovieInfo(),
                  const SizedBox(height: 20),
                  _buildDateSelector(),
                  const SizedBox(height: 20),
                  _buildCinemaSelector(),
                  const SizedBox(height: 20),
                  _buildTimeSelector(times),
                  const SizedBox(height: 24),
                  _buildSeatButton(selectedDate, selectedCinema, times),
                ],
              ),
            ),
    );
  }

  Widget _buildMovieInfo() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đặt vé xem phim',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.movie.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${widget.movie.genre} | ${widget.movie.duration} phút',
          style: const TextStyle(color: Color(0xFFB9B9C3)),
        ),
      ],
    ),
  );

  Widget _buildDateSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Chọn ngày',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: availableDates.length,
          itemBuilder: (_, i) {
            final date = availableDates[i];
            final isToday = date.day == now.day && date.month == now.month;
            final isSelected = selectedDayIndex == i;
            return GestureDetector(
              onTap: () => setState(() => selectedDayIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B1E9B)
                      : const Color(0xFF151521),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      isToday ? 'Hôm nay' : '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _buildCinemaSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Chọn rạp',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cinemas.length,
        itemBuilder: (_, i) {
          final c = cinemas[i];
          final isSelected = selectedCinemaIndex == i;
          return GestureDetector(
            onTap: () => setState(() => selectedCinemaIndex = i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B1E9B)
                    : const Color(0xFF151521),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: c.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.location_city,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _buildTimeSelector(List<Map<String, TimeOfDay>> times) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Chọn giờ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: times.length,
          itemBuilder: (_, i) {
            final isSelected = selectedTimeIndex == i;
            final s = times[i]['start']!, e = times[i]['end']!;
            return GestureDetector(
              onTap: () => setState(() => selectedTimeIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B1E9B)
                      : const Color(0xFF151521),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${_fmt(s)} ~ ${_fmt(e)}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _buildSeatButton(
    DateTime selectedDate,
    Cinema? selectedCinema,
    List<Map<String, TimeOfDay>> times,
  ) {
    final valid =
        selectedCinema != null &&
        times.isNotEmpty &&
        selectedTimeIndex < times.length;
    return ElevatedButton(
      onPressed: valid
          ? () {
              final start = times[selectedTimeIndex]['start']!;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeatSelectionScreen(
                    movie: widget.movie,
                    selectedDate: selectedDate,
                    selectedCinema: selectedCinema.name,
                    selectedTime: start,
                  ),
                ),
              );
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B1E9B),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_seat, size: 20),
          SizedBox(width: 8),
          Text(
            'Chọn ghế',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
