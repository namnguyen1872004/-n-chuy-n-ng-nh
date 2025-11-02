// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/movie.dart';
import '../models/cinema_model.dart';
import 'seat_selection_screen.dart';

/// ===============================================================
/// BOOKING SCREEN
/// - Chọn NGÀY → RẠP → KHUNG GIỜ (khung giờ tùy theo openHours của từng rạp)
/// - Dùng Realtime Database để lấy danh sách rạp
/// - Có lọc rạp theo movie.cinemas nếu dữ liệu phim cung cấp
/// ===============================================================
class BookingScreen extends StatefulWidget {
  final Movie movie;
  const BookingScreen({super.key, required this.movie});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ------------------ Firebase ------------------
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ------------------ “Thời gian hiện tại” (để ẩn giờ đã qua) ------------------
  DateTime _now = DateTime.now();
  Timer? _nowTick;
  static const Duration _nowTickInterval = Duration(minutes: 1);

  // ------------------ Lựa chọn của người dùng ------------------
  int _dayIndex = 0; // index của ngày
  int _cinemaIndex = 0; // index của rạp
  int _timeIndex = 0; // index của khung giờ

  // ------------------ Dữ liệu hiển thị ------------------
  List<DateTime> _dates = []; // 6 ngày: hôm nay -> +5 ngày
  List<Cinema> _cinemas = [];
  bool _loading = true;

  // Fallback slot khi không parse được openHours: [startHour, startMinute, endHour, endMinute]
  static const List<List<int>> _fallbackSlots = <List<int>>[
    [9, 0, 11, 0],
    [13, 0, 15, 0],
    [17, 0, 19, 0],
    [20, 0, 22, 0],
  ];

  // =============================================================
  // LIFECYCLE
  // =============================================================
  @override
  void initState() {
    super.initState();
    _buildDates();
    _fetchCinemas();
    // Cập nhật _now mỗi phút để ẩn slot đã qua khi là “Hôm nay”
    _nowTick = Timer.periodic(_nowTickInterval, (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _nowTick?.cancel();
    super.dispose();
  }

  // =============================================================
  // DATA: Lấy rạp
  // =============================================================
  Future<void> _fetchCinemas() async {
    try {
      final snap = await _db.child('cinemas').get();
      final List<Cinema> loaded = [];

      if (snap.exists) {
        final raw = snap.value;
        if (raw is Map) {
          raw.forEach((_, v) {
            if (v is Map) {
              loaded.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
            }
          });
        } else if (raw is List) {
          for (final v in raw) {
            if (v is Map)
              loaded.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
          }
        }
      }

      // Nếu movie.cinemas có, chỉ giữ lại rạp có trong map này
      final filtered = _filterCinemasByMovie(loaded, widget.movie);

      if (!mounted) return;
      setState(() {
        _cinemas = filtered;
        _loading = false;
        _fixIndexes(); // đảm bảo các index hợp lệ khi dữ liệu đã có
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu rạp: $e')));
    }
  }

  List<Cinema> _filterCinemasByMovie(List<Cinema> all, Movie m) {
    final link = m.cinemas;
    if (link == null || link.isEmpty)
      return all; // không có ràng buộc → giữ nguyên
    final allowed = link.keys.toSet();
    return all.where((c) => allowed.contains(c.id)).toList();
  }

  // =============================================================
  // DATES & TIME SLOTS
  // =============================================================
  /// Tạo 6 ngày: hôm nay → 5 ngày sau
  void _buildDates() {
    final base = DateTime(_now.year, _now.month, _now.day);
    _dates = List.generate(6, (i) => base.add(Duration(days: i)));
  }

  /// Parse openHours thành slot [hh, mm, hh, mm]
  /// Hỗ trợ:
  ///  - "09:00-11:00, 14:00-16:00"
  ///  - "09:00 - 23:00" → auto chia 4 khung
  List<List<int>> _parseSlots(String openHours) {
    try {
      final text = openHours.trim();
      if (text.isEmpty) return _fallbackSlots;

      // Nhiều khoảng “a-b, c-d”
      if (text.contains(',')) {
        return text.split(',').map((part) {
          final range = part.trim().split('-');
          final s = range[0].trim().split(':').map(int.parse).toList();
          final e = range[1].trim().split(':').map(int.parse).toList();
          return [s[0], s[1], e[0], e[1]];
        }).toList();
      }

      // Một khoảng duy nhất “a-b” → chia 4
      if (text.contains('-')) {
        final range = text.split('-');
        final s = range[0].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final e = range[1].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final sh = int.tryParse(s[0]) ?? 9;
        final eh = int.tryParse(e[0]) ?? 23;

        final diff = (eh - sh).clamp(1, 24);
        final step = (diff ~/ 4).clamp(1, 24);

        final out = <List<int>>[];
        for (int i = 0; i < 4; i++) {
          final startH = sh + i * step;
          final endH = (i == 3) ? eh : (startH + step);
          out.add([startH, 0, endH, 0]);
        }
        return out;
      }

      return _fallbackSlots;
    } catch (_) {
      return _fallbackSlots;
    }
  }

  /// Ẩn slot đã qua nếu đang chọn “Hôm nay”
  List<Map<String, TimeOfDay>> _buildTimeOfDaySlots(Cinema? cinema) {
    final slots = (cinema == null)
        ? _fallbackSlots
        : _parseSlots(cinema.openHours);

    final list = slots
        .map(
          (s) => {
            'start': TimeOfDay(hour: s[0], minute: s[1]),
            'end': TimeOfDay(hour: s[2], minute: s[3]),
          },
        )
        .toList();

    if (_isToday(_dates[_dayIndex])) {
      final nowTod = TimeOfDay.fromDateTime(_now);
      // Giữ slot có start sau “bây giờ”
      return list.where((m) => _isAfter(m['start']!, nowTod)).toList();
    }
    return list;
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour > b.hour;
    return a.minute > b.minute;
    // Nếu muốn “>=” thì thay bằng >= ở trên.
  }

  bool _isToday(DateTime d) =>
      d.year == _now.year && d.month == _now.month && d.day == _now.day;

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDateShort(DateTime d) {
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
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}';
  }

  // =============================================================
  // UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    // Bảo vệ index khi dữ liệu đổi
    _fixIndexes();

    final selectedCinema = _cinemas.isEmpty ? null : _cinemas[_cinemaIndex];
    final times = _buildTimeOfDaySlots(selectedCinema);

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            )
          : _cinemas.isEmpty
          ? const Center(
              child: Text(
                'Không có rạp khả dụng!',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _movieHeader(),
                  const SizedBox(height: 20),
                  _dateSelector(),
                  const SizedBox(height: 20),
                  _cinemaSelector(),
                  const SizedBox(height: 20),
                  _timeSelector(times),
                  const SizedBox(height: 24),
                  _seatButton(times, selectedCinema),
                ],
              ),
            ),
    );
  }

  // ------------ Widgets nhỏ (có chú thích) ------------

  /// Thông tin nhanh của phim
  Widget _movieHeader() => Container(
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

  /// Chọn ngày (6 ngày)
  Widget _dateSelector() => Column(
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
          itemCount: _dates.length,
          itemBuilder: (_, i) {
            final d = _dates[i];
            final selected = i == _dayIndex;
            final isToday = _isToday(d);
            return GestureDetector(
              onTap: () => setState(() {
                _dayIndex = i;
                _timeIndex = 0; // đổi ngày -> reset giờ
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF8B1E9B)
                      : const Color(0xFF151521),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _fmtDateShort(d),
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      isToday ? 'Hôm nay' : '${d.day}',
                      style: TextStyle(
                        fontSize: 16,
                        color: selected ? Colors.white : Colors.white70,
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

  /// Chọn rạp
  Widget _cinemaSelector() => Column(
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
        itemCount: _cinemas.length,
        itemBuilder: (_, i) {
          final c = _cinemas[i];
          final selected = i == _cinemaIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _cinemaIndex = i;
              _timeIndex = 0; // đổi rạp -> reset giờ
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
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
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected
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

  /// Chọn khung giờ (theo rạp)
  Widget _timeSelector(List<Map<String, TimeOfDay>> times) => Column(
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
      if (times.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151521),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Không có khung giờ phù hợp!',
            style: TextStyle(color: Colors.white70),
          ),
        )
      else
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: times.length,
            itemBuilder: (_, i) {
              final selected = i == _timeIndex;
              final s = times[i]['start']!;
              final e = times[i]['end']!;
              return GestureDetector(
                onTap: () => setState(() => _timeIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF8B1E9B)
                        : const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${_fmtTod(s)} ~ ${_fmtTod(e)}',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected
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

  /// Nút chuyển sang chọn ghế
  Widget _seatButton(List<Map<String, TimeOfDay>> times, Cinema? cinema) {
    final valid =
        cinema != null && times.isNotEmpty && _timeIndex < times.length;
    return ElevatedButton(
      onPressed: !valid
          ? null
          : () {
              final start = times[_timeIndex]['start']!;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeatSelectionScreen(
                    movie: widget.movie,
                    selectedDate: _dates[_dayIndex],
                    selectedCinema: cinema!.name,
                    selectedTime: start,
                  ),
                ),
              );
            },
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

  // =============================================================
  // Bảo vệ Index (tránh crash khi dữ liệu đổi)
  // =============================================================
  void _fixIndexes() {
    if (_dates.isEmpty) _buildDates();
    _dayIndex = _clamp(_dayIndex, 0, (_dates.length - 1));

    _cinemaIndex = _clamp(_cinemaIndex, 0, (_cinemas.length - 1));

    // _timeIndex sẽ được “ghìm” ở thời điểm render dựa trên danh sách times thực tế.
    if (_timeIndex < 0) _timeIndex = 0;
  }

  int _clamp(int v, int min, int max) {
    if (max < min) return min;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
