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
/// Mục tiêu: Quy trình đặt vé theo thứ tự NGÀY → RẠP → KHUNG GIỜ → GHẾ
/// - Dữ liệu rạp lấy từ Firebase Realtime Database (path '/cinemas') bằng .get()
/// - Nếu Movie có map 'cinemas' (id rạp), sẽ lọc chỉ hiển thị các rạp đó
/// - Khung giờ lấy từ 'openHours' của từng rạp; nếu format lạ → fallback slot
/// - Hôm nay: tự ẩn slot đã qua nhờ Timer cập nhật _now mỗi phút
/// ===============================================================
class BookingScreen extends StatefulWidget {
  final Movie
  movie; // Phim đang đặt, chứa title/genre/duration và (có thể) map cinemas
  const BookingScreen({super.key, required this.movie});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ------------------ Firebase ------------------
  // Tạo DatabaseReference gốc để gọi Realtime Database
  // Sẽ .child('cinemas').get() để đọc danh sách rạp (one-shot)
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ------------------ “Thời gian hiện tại” (để ẩn giờ đã qua) ------------------
  // _now: thời điểm hiện tại; _nowTick: timer cập nhật mỗi phút
  // Khi chọn “Hôm nay”, chỉ show slot có start > _now
  DateTime _now = DateTime.now();
  Timer? _nowTick;
  static const Duration _nowTickInterval = Duration(minutes: 1);

  // ------------------ Lựa chọn của người dùng ------------------
  // Lưu index cho từng lựa chọn; giúp render trạng thái “đang chọn”
  int _dayIndex = 0; // index của ngày
  int _cinemaIndex = 0; // index của rạp
  int _timeIndex = 0; // index của khung giờ

  // ------------------ Dữ liệu hiển thị ------------------
  // _dates: 6 ngày (hôm nay -> +5); _cinemas: danh sách rạp sau khi load & lọc
  // _loading: trạng thái đang tải dữ liệu rạp
  List<DateTime> _dates = [];
  List<Cinema> _cinemas = [];
  bool _loading = true;

  // ------------------ Fallback slot ------------------
  // Dùng khi openHours rỗng/format lạ để UI vẫn hoạt động
  // Mỗi phần tử: [startHour, startMinute, endHour, endMinute]
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
    _buildDates(); // Chuẩn bị danh sách 6 ngày (normalize về 00:00)
    _fetchCinemas(); // Đọc rạp từ Firebase /cinemas (one-shot)
    // Cập nhật _now mỗi phút để lọc slot đã qua khi ngày đang chọn là “Hôm nay”
    _nowTick = Timer.periodic(_nowTickInterval, (_) {
      if (!mounted) return; // Bảo vệ: widget có thể bị dispose
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _nowTick?.cancel(); // Hủy timer để tránh rò rỉ/bị gọi sau dispose
    super.dispose();
  }

  // =============================================================
  // DATA: Lấy rạp
  // =============================================================
  Future<void> _fetchCinemas() async {
    try {
      // 1) Gọi Realtime DB path '/cinemas' bằng .get() (one-shot, không realtime)
      final snap = await _db.child('cinemas').get();
      final List<Cinema> loaded = [];

      if (snap.exists) {
        // 2) snapshot.value có thể là Map (id->{...}) hoặc List ([{...},{...}])
        final raw = snap.value;
        if (raw is Map) {
          // Trường hợp Map: duyệt value -> ép kiểu -> đưa vào fromMap
          raw.forEach((_, v) {
            if (v is Map) {
              loaded.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
            }
          });
        } else if (raw is List) {
          // Trường hợp List: duyệt từng phần tử -> ép kiểu -> fromMap
          for (final v in raw) {
            if (v is Map) {
              loaded.add(Cinema.fromMap(Map<String, dynamic>.from(v)));
            }
          }
        }
      }

      // 3) Lọc theo phim nếu Movie có map 'cinemas' (ví dụ { cgv001: true, lotte003: true })
      // Nếu không có -> giữ nguyên toàn bộ rạp đã load
      final filtered = _filterCinemasByMovie(loaded, widget.movie);

      if (!mounted) return; // Tránh setState khi widget đã bị dispose
      setState(() {
        _cinemas = filtered; // cập nhật danh sách rạp cho UI
        _loading = false; // tắt trạng thái loading
        _fixIndexes(); // đảm bảo index đang chọn không vượt biên
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false); // Tắt loading khi có lỗi
      // Báo lỗi ra UI — thường gặp: mất mạng, rules DB chặn, value null…
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu rạp: $e')));
    }
  }

  // Lọc danh sách rạp dựa trên Movie.cinemas:
  // - Nếu m.cinemas null/empty → không ràng buộc, trả toàn bộ 'all'
  // - Nếu có → chỉ giữ rạp có id nằm trong m.cinemas.keys
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
  /// Dùng _now (normalize về 00:00) để so sánh/mốc “hôm nay” ổn định
  void _buildDates() {
    final base = DateTime(_now.year, _now.month, _now.day);
    _dates = List.generate(6, (i) => base.add(Duration(days: i)));
  }

  /// Parse openHours thành list slot [hh, mm, hh, mm]
  /// Hỗ trợ định dạng phổ biến của rạp:
  /// 1) "09:00-11:00, 14:00-16:00"  (nhiều khoảng → tách bằng ',')
  /// 2) "09:00 - 23:00"             (một khoảng → tự chia 4 khúc đều nhau theo giờ)
  /// Nếu rỗng/format lạ → trả fallback để UI không bị rỗng/đơ
  List<List<int>> _parseSlots(String openHours) {
    try {
      final text = openHours.trim();
      if (text.isEmpty) return _fallbackSlots;

      // Nhiều khoảng “a-b, c-d, ...”
      if (text.contains(',')) {
        return text.split(',').map((part) {
          final range = part.trim().split('-'); // "a-b"
          final s = range[0]
              .trim()
              .split(':')
              .map(int.parse)
              .toList(); // a -> [hh,mm]
          final e = range[1]
              .trim()
              .split(':')
              .map(int.parse)
              .toList(); // b -> [hh,mm]
          return [s[0], s[1], e[0], e[1]]; // [sh, sm, eh, em]
        }).toList();
      }

      // Một khoảng duy nhất “a-b” → chia 4 khúc đều: (ví dụ 09-23 → 09-14, 14-18, 18-21, 21-23)
      if (text.contains('-')) {
        final range = text.split('-');
        // Loại ký tự không phải số hoặc ':' để tránh lỗi parse
        final s = range[0].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final e = range[1].replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final sh = int.tryParse(s[0]) ?? 9; // default 9 nếu parse lỗi
        final eh = int.tryParse(e[0]) ?? 23; // default 23 nếu parse lỗi

        final diff = (eh - sh).clamp(1, 24); // độ dài khoảng (theo giờ), min 1h
        final step = (diff ~/ 4).clamp(
          1,
          24,
        ); // mỗi khúc ~ diff/4, tối thiểu 1h

        final out = <List<int>>[];
        for (int i = 0; i < 4; i++) {
          final startH = sh + i * step; // giờ bắt đầu khúc i
          final endH = (i == 3)
              ? eh
              : (startH + step); // khúc cuối kết thúc đúng eh
          out.add([startH, 0, endH, 0]); // phút = 0 cho đơn giản
        }
        return out;
      }

      // Không khớp định dạng đã biết → fallback
      return _fallbackSlots;
    } catch (_) {
      // Parse lỗi → fallback để không làm app crash
      return _fallbackSlots;
    }
  }

  /// Tạo list TimeOfDay cho UI từ slot số, đồng thời ẨN slot đã qua nếu ngày đang chọn là “Hôm nay”
  List<Map<String, TimeOfDay>> _buildTimeOfDaySlots(Cinema? cinema) {
    // Nếu chưa chọn rạp -> dùng fallback (để UI vẫn hiển thị ổn định)
    final slots = (cinema == null)
        ? _fallbackSlots
        : _parseSlots(cinema.openHours);

    // Chuyển mỗi slot [hh,mm,hh,mm] → {'start': TimeOfDay, 'end': TimeOfDay}
    final list = slots
        .map(
          (s) => {
            'start': TimeOfDay(hour: s[0], minute: s[1]),
            'end': TimeOfDay(hour: s[2], minute: s[3]),
          },
        )
        .toList();

    // Nếu đang chọn “Hôm nay”, loại bỏ slot có start <= thời điểm hiện tại
    if (_isToday(_dates[_dayIndex])) {
      final nowTod = TimeOfDay.fromDateTime(_now);
      return list.where((m) => _isAfter(m['start']!, nowTod)).toList();
    }
    return list;
  }

  // So sánh TimeOfDay: a có "sau" b không? (ưu tiên so sánh giờ, rồi đến phút)
  // Dùng cho việc ẩn slot đã qua trong ngày hôm nay
  bool _isAfter(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour > b.hour;
    return a.minute > b.minute;
    // Nếu muốn giữ cả slot bắt đầu đúng “bây giờ”, đổi thành >=
  }

  // Kiểm tra DateTime d có phải hôm nay (so với _now) không
  bool _isToday(DateTime d) =>
      d.year == _now.year && d.month == _now.month && d.day == _now.day;

  // Định dạng "HH:mm" cho TimeOfDay
  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Định dạng ngày ngắn gọn: "Tn, dd Thm" (vd "T3, 5 Th4")
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
    // Mỗi lần build: đảm bảo các index không vượt biên (khi dữ liệu đổi bất chợt)
    _fixIndexes();

    // Rạp đang chọn (nếu có), và danh sách khung giờ dựa trên rạp + ngày
    final selectedCinema = _cinemas.isEmpty ? null : _cinemas[_cinemaIndex];
    final times = _buildTimeOfDaySlots(selectedCinema);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Quay lại màn trước
        ),
        title: Text(
          widget.movie.title, // Hiển thị tên phim hiện tại
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 3 trạng thái thân màn:
      // 1) Đang tải rạp -> spinner
      // 2) Tải xong nhưng không có rạp -> thông báo
      // 3) Có dữ liệu -> hiển thị các lựa chọn
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
                  _movieHeader(), // Thông tin nhanh của phim
                  const SizedBox(height: 20),
                  _dateSelector(), // Chọn ngày (6 ô ngang)
                  const SizedBox(height: 20),
                  _cinemaSelector(), // Danh sách rạp (dọc)
                  const SizedBox(height: 20),
                  _timeSelector(times), // Khung giờ (ngang) theo rạp/ngày
                  const SizedBox(height: 24),
                  _seatButton(times, selectedCinema), // Nút sang chọn ghế
                ],
              ),
            ),
    );
  }

  // ------------ Widgets nhỏ (tách riêng để code dễ đọc/bảo trì) ------------

  /// Header phim: tiêu đề màn + tên phim + thể loại + thời lượng
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
          widget.movie.title, // Lấy từ tham số truyền vào màn
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

  /// Bộ chọn ngày (6 ngày: hôm nay -> +5)
  /// - CUỘN ngang bằng ListView.builder
  /// - Chạm để set _dayIndex, đồng thời reset _timeIndex (tránh lệch giờ cũ)
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
                _dayIndex = i; // chọn ngày mới
                _timeIndex = 0; // reset chọn giờ khi đổi ngày
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
                      _fmtDateShort(d), // "Tn, dd Thm"
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

  /// Bộ chọn rạp
  /// - Danh sách dọc (ListView.builder) lồng trong SingleChildScrollView → cần shrinkWrap + NeverScrollableScrollPhysics
  /// - Mỗi item: ảnh rạp (CachedNetworkImage) + tên rạp
  /// - Chạm để set _cinemaIndex, đồng thời reset _timeIndex
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
        shrinkWrap: true, // Cho phép render đủ chiều cao
        physics: const NeverScrollableScrollPhysics(), // Cuộn theo cha
        itemCount: _cinemas.length,
        itemBuilder: (_, i) {
          final c = _cinemas[i];
          final selected = i == _cinemaIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _cinemaIndex = i; // chọn rạp mới
              _timeIndex = 0; // reset giờ khi đổi rạp
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
                  // Ảnh rạp — có cache, fallback icon nếu URL lỗi
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
                      c.name, // Tên rạp
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

  /// Bộ chọn khung giờ
  /// - Nếu times rỗng (không có slot phù hợp) → hiện thông báo
  /// - Nếu có → ListView.builder ngang, chọn 1 slot → set _timeIndex
  /// - Chuỗi hiển thị: "HH:mm ~ HH:mm"
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
              final s = times[i]['start']!; // TimeOfDay bắt đầu
              final e = times[i]['end']!; // TimeOfDay kết thúc
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
  /// - Chỉ enable khi: đã có rạp, có ít nhất 1 slot, và _timeIndex hợp lệ
  /// - Bấm → Navigator.push sang SeatSelectionScreen, truyền đủ dữ liệu đã chọn
  Widget _seatButton(List<Map<String, TimeOfDay>> times, Cinema? cinema) {
    final valid =
        cinema != null && times.isNotEmpty && _timeIndex < times.length;
    return ElevatedButton(
      onPressed: !valid
          ? null
          : () {
              final start = times[_timeIndex]['start']!; // TimeOfDay bắt đầu
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeatSelectionScreen(
                    movie: widget.movie, // Dữ liệu phim
                    selectedDate: _dates[_dayIndex], // Ngày đã chọn
                    selectedCinema: cinema!.name, // Tên rạp đã chọn
                    selectedTime: start, // Giờ bắt đầu đã chọn
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
  // Bảo vệ Index (tránh crash khi dữ liệu đổi hoặc đang tải)
  // =============================================================
  void _fixIndexes() {
    if (_dates.isEmpty) _buildDates(); // đảm bảo luôn có 6 ngày
    _dayIndex = _clamp(_dayIndex, 0, (_dates.length - 1));

    _cinemaIndex = _clamp(_cinemaIndex, 0, (_cinemas.length - 1));

    // _timeIndex sẽ được “ghìm” theo times thực tế khi render (_timeSelector)
    if (_timeIndex < 0) _timeIndex = 0;
  }

  // Hàm clamp cơ bản: giữ v trong [min, max] an toàn (tránh out-of-range)
  int _clamp(int v, int min, int max) {
    if (max < min) return min; // ví dụ: list rỗng → max < min
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
