import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/movie.dart';
import 'seat_selection_screen.dart';

class BookingScreen extends StatefulWidget {
  final Movie movie;

  const BookingScreen({super.key, required this.movie});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Current time (kept updated so UI like "Hôm nay" updates in real-time)
  DateTime now = DateTime.now();

  Timer? _nowTimer;
  int selectedDayIndex = 0;
  int selectedCinemaIndex = 0;
  int selectedTimeIndex = 0;

  // ======= DỮ LIỆU CHUNG =======

  // Các mốc giờ chuẩn — giống MovieSelectionScreen (demo)
  // Mỗi phần tử: [startHour, startMinute, endHour, endMinute]
  static const List<List<int>> _momoSlots = [
    [8, 40, 10, 57],
    [9, 40, 11, 57],
    [10, 10, 12, 27],
    [11, 0, 13, 17],
    [11, 30, 13, 44],
    [12, 0, 14, 17],
    [12, 30, 14, 47],
    [13, 20, 15, 37],
    [14, 20, 16, 37],
    [14, 50, 17, 7],
    [15, 40, 17, 57],
    [16, 40, 18, 57],
  ];

  // format TimeOfDay -> 'HH:mm'
  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Ngày cho selector (will be rebuilt from `now` so it follows real time)
  List<DateTime> availableDates = [];

  // Danh sách rạp
  final List<Map<String, dynamic>> availableCinemas = [
    {
      'name': 'CGV Vincom Mega Mall',
      'address': 'Vincom Mega Mall Royal City, Thanh Xuân, Hà Nội',
      'distance': 2.5,
      'imageUrl': 'https://cdn.xanhsm.com/2025/02/bf178809-royal-city-5.jpg',
      // Custom slots for this cinema (startHour,startMin,endHour,endMin)
      'slots': [
        [8, 50, 11, 7],
        [11, 30, 13, 44],
        [14, 0, 16, 17],
      ],
    },
    {
      'name': 'Lotte Cinema Times City',
      'address': 'Times City, Hai Bà Trưng, Hà Nội',
      'distance': 1.8,
      'imageUrl':
          'https://img.tripi.vn/cdn-cgi/image/width=700,height=700/https://gcs.tripi.vn/public-tripi/tripi-feed/img/486420RoV/anh-mo-ta.png',
      // No custom slots -> will use global demo slots
    },
    {
      'name': 'BHD Star Cineplex Aeon Mall Hà Đông',
      'address': 'Aeon Mall Hà Đông, Hà Nội',
      'distance': 3.2,
      'imageUrl':
          'https://www.bhdstar.vn/wp-content/uploads/2023/12/0000000009.png',
      'slots': [
        [9, 0, 11, 17],
        [12, 0, 14, 17],
        [15, 0, 17, 7],
        [18, 30, 20, 47],
      ],
    },
  ];

  String getFormattedDate(DateTime date) {
    final days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final months = [
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
  Widget build(BuildContext context) {
    final selectedDate = availableDates.isNotEmpty
        ? availableDates[selectedDayIndex.clamp(0, availableDates.length - 1)]
        : DateTime.now();
    final selectedCinema = availableCinemas[selectedCinemaIndex];

    // ✅ Lấy slot từ rạp đang chọn (nếu rạp có 'slots' riêng) hoặc fallback sang global _momoSlots
    final rawSlots = (selectedCinema['slots'] is List)
        ? List<List<int>>.from(
            (selectedCinema['slots'] as List).map((e) => List<int>.from(e)),
          )
        : _momoSlots;

    final times = rawSlots
        .map(
          (t) => {
            'start': TimeOfDay(hour: t[0], minute: t[1]),
            'end': TimeOfDay(hour: t[2], minute: t[3]),
          },
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDED)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header movie info
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF151521),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đặt vé xem phim',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.movie.genre} | ${widget.movie.duration} phút',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB9B9C3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Chọn ngày
            const Text(
              'Chọn ngày',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEDEDED),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableDates.length,
                itemBuilder: (context, index) {
                  final date = availableDates[index];
                  final isSelected = index == selectedDayIndex;
                  final isToday =
                      date.day == now.day &&
                      date.month == now.month &&
                      date.year == now.year;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDayIndex = index;
                        selectedCinemaIndex = 0;
                        selectedTimeIndex = 0;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8B1E9B)
                            : const Color(0xFF151521),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8B1E9B)
                              : const Color(0xFF222230),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            getFormattedDate(date),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFEDEDED),
                            ),
                          ),
                          Text(
                            isToday ? 'Hôm nay' : '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFEDEDED),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Chọn rạp
            const Text(
              'Chọn rạp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEDEDED),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableCinemas.length,
              itemBuilder: (context, index) {
                final cinema = availableCinemas[index];
                final isSelected = index == selectedCinemaIndex;
                return GestureDetector(
                  onTap: () => setState(() {
                    selectedCinemaIndex = index;
                    selectedTimeIndex = 0;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B1E9B)
                          : const Color(0xFF151521),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B1E9B)
                            : const Color(0xFF222230),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: cinema['imageUrl'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFF222230),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8B1E9B),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.location_city,
                              color: Color(0xFFB9B9C3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cinema['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFEDEDED),
                                ),
                              ),
                              Text(
                                cinema['address'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.white70
                                      : const Color(0xFFB9B9C3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Chọn giờ
            const Text(
              'Chọn giờ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEDEDED),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: times.length,
                itemBuilder: (context, index) {
                  final t = times[index];
                  final start = t['start'] as TimeOfDay;
                  final end = t['end'] as TimeOfDay;
                  final isSelected = index == selectedTimeIndex;
                  return GestureDetector(
                    onTap: () => setState(() => selectedTimeIndex = index),
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
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8B1E9B)
                              : const Color(0xFF222230),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${_fmt(start)} ~ ${_fmt(end)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFEDEDED),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Nút chọn ghế
            ElevatedButton(
              onPressed:
                  (selectedTimeIndex >= 0 && selectedTimeIndex < times.length)
                  ? () {
                      final start =
                          times[selectedTimeIndex]['start'] as TimeOfDay;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeatSelectionScreen(
                            movie: widget.movie,
                            selectedDate: selectedDate,
                            selectedCinema: selectedCinema['name'] as String,
                            selectedTime: start,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E9B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // initialize dynamic availableDates based on current time
    _rebuildAvailableDates();
    // update `now` every minute so the "Hôm nay" marker and date list stay correct
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final prevDay = DateTime(now.year, now.month, now.day);
      now = DateTime.now();
      final newDay = DateTime(now.year, now.month, now.day);
      // If the day changed (midnight) rebuild availableDates and ensure selected index is valid
      if (newDay.difference(prevDay).inDays != 0) {
        setState(() {
          _rebuildAvailableDates();
          if (selectedDayIndex >= availableDates.length) selectedDayIndex = 0;
        });
      } else {
        // still update `now` so "Hôm nay" label is accurate within the same day
        setState(() {});
      }
    });
  }

  void _rebuildAvailableDates() {
    final base = DateTime(now.year, now.month, now.day);
    availableDates = List.generate(6, (i) => base.add(Duration(days: i)));
    // make sure selectedDayIndex remains in range
    if (selectedDayIndex >= availableDates.length) selectedDayIndex = 0;
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    super.dispose();
  }
}
