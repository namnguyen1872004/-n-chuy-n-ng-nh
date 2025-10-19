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
  // Demo “now”
  final DateTime now = DateTime(2025, 10, 18, 2, 0, 0);

  int selectedDayIndex = 0;
  int selectedCinemaIndex = 0;
  int selectedTimeIndex = 0;

  // ======= DỮ LIỆU CHUNG =======

  // Các mốc giờ chuẩn — giống MovieSelectionScreen (demo)
  // MovieSelectionScreen dùng các cặp giờ start/end như:
  // 08:40~10:57, 09:40~11:57, 10:10~12:27, ...
  // Ở Booking chỉ cần hiển thị giờ bắt đầu cho đồng bộ UI.
  static const List<String> _momoSlots = [
    '08:40',
    '09:40',
    '10:10',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:20',
    '14:20',
    '14:50',
    '15:40',
    '16:40',
  ];

  // parse 'HH:mm' -> TimeOfDay
  TimeOfDay _parseTimeOfDay(String s) {
    final p = s.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  // format TimeOfDay -> 'HH:mm'
  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Ngày cho selector
  final List<DateTime> availableDates = List.generate(
    6,
    (i) => DateTime(2025, 10, 18).add(Duration(days: i)),
  );

  // Danh sách rạp (KHÔNG gắn showtimes tại đây nữa để đồng bộ giờ)
  final List<Map<String, dynamic>> availableCinemas = [
    {
      'name': 'CGV Vincom Mega Mall',
      'address': 'Vincom Mega Mall Royal City, Thanh Xuân, Hà Nội',
      'distance': 2.5,
      'imageUrl': 'https://cdn.xanhsm.com/2025/02/bf178809-royal-city-5.jpg',
    },
    {
      'name': 'Lotte Cinema Times City',
      'address': 'Times City, Hai Bà Trưng, Hà Nội',
      'distance': 1.8,
      'imageUrl':
          'https://img.tripi.vn/cdn-cgi/image/width=700,height=700/https://gcs.tripi.vn/public-tripi/tripi-feed/img/486420RoV/anh-mo-ta.png',
    },
    {
      'name': 'BHD Star Cineplex Aeon Mall Hà Đông',
      'address': 'Aeon Mall Hà Đông, Hà Nội',
      'distance': 3.2,
      'imageUrl':
          'https://www.bhdstar.vn/wp-content/uploads/2023/12/0000000009.png',
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
    final selectedDate = availableDates[selectedDayIndex];
    final selectedCinema = availableCinemas[selectedCinemaIndex];

    // ✅ DÙNG SLOT CHUẨN GIỐNG MovieSelectionScreen
    final List<TimeOfDay> times = _momoSlots.map(_parseTimeOfDay).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đặt vé xem phim',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.movie.genre} | ${widget.movie.duration} phút',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Chọn ngày
            const Text(
              'Chọn ngày',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
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
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            isToday ? 'Hôm nay' : '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                              color: Colors.grey[300],
                            ),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.location_city),
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
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                cinema['address'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey[600],
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

            // Chọn giờ — dùng TimeOfDay từ _momoSlots (đồng bộ MovieSelectionScreen)
            const Text(
              'Chọn giờ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: times.length,
                itemBuilder: (context, index) {
                  final t = times[index];
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
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _fmt(t), // ✅ hiển thị y hệt MovieSelectionScreen
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
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
                      final timeOfDay =
                          times[selectedTimeIndex]; // TimeOfDay chuẩn
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeatSelectionScreen(
                            movie: widget.movie,
                            selectedDate: selectedDate,
                            selectedCinema: selectedCinema['name'] as String,
                            selectedTime: timeOfDay,
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
}
