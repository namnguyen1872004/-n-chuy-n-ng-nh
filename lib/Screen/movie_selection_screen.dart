import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/cinema_model.dart';
import '../models/movie.dart';
import '../models/showtime.dart';
import 'seat_selection_screen.dart';

class MovieSelectionScreen extends StatefulWidget {
  final Cinema cinema;
  const MovieSelectionScreen({super.key, required this.cinema});

  @override
  State<MovieSelectionScreen> createState() => _CinemaShowtimesScreenState();
}

class _CinemaShowtimesScreenState extends State<MovieSelectionScreen> {
  final _db = FirebaseDatabase.instance.ref();

  // ngày & khung giờ
  late final List<DateTime> days;
  int selectedDay = 0;
  int selectedSlot = 0; // 0 = Tất cả

  // dữ liệu
  bool loading = true;
  List<Movie> movies = [];
  final Map<String, List<Showtime>> showtimesByMovie = {};

  @override
  void initState() {
    super.initState();
    days = List.generate(6, (i) {
      final d = DateTime.now().add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
    _loadAll();
  }

  // --- Helpers để xác định "đang chiếu" ---
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) {
      // giả định millis
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is String) {
      // yyyy-MM-dd hoặc ISO-8601
      return DateTime.tryParse(v);
    }
    return null;
  }

  bool _looksLikeNowShowing(Map<String, dynamic> m) {
    // Các cờ boolean thường gặp
    for (final key in ['isShowing', 'nowShowing', 'isNowShowing']) {
      final v = m[key];
      if (v is bool) return v; // true => đang chiếu
    }
    // comingSoon true => loại
    if (m['comingSoon'] is bool && m['comingSoon'] == true) return false;

    // status/category bằng chuỗi
    for (final key in ['status', 'category', 'type']) {
      final v = m[key];
      if (v is String) {
        final s = v.toLowerCase();
        final hasNow =
            s.contains('đang') || s.contains('dang') || s.contains('now');
        final hasSoon =
            s.contains('sắp') || s.contains('sap') || s.contains('coming');
        if (hasNow && !hasSoon) return true;
        if (hasSoon && !hasNow) return false;
      }
    }

    // Ngày phát hành: nếu <= hôm nay => coi là đang chiếu
    final rd = _parseDate(m['releaseDate'] ?? m['premiereDate']);
    if (rd != null) {
      final today = DateTime.now();
      final t = DateTime(today.year, today.month, today.day);
      final r = DateTime(rd.year, rd.month, rd.day);
      return r.isBefore(t) || r.isAtSameMomentAs(t);
    }

    // Nếu không có thông tin gì => KHÔNG lọc (giữ lại)
    return true;
  }

  Future<void> _loadAll() async {
    try {
      final snap = await _db.child('movies').get();
      final val = snap.value;

      final map = <String, dynamic>{};
      if (val is Map) {
        map.addAll(Map<String, dynamic>.from(val));
      } else if (val is List) {
        for (var i = 0; i < val.length; i++) {
          map[i.toString()] = val[i];
        }
      }

      final parsed = <Movie>[];
      map.forEach((id, data) {
        if (data is! Map) return;
        // Chuẩn hóa map để kiểm tra cờ & tạo Movie
        final raw = Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)),
        );

        // ❗ LỌC: chỉ nhận phim đang chiếu
        if (!_looksLikeNowShowing(raw)) return;

        raw['id'] = id; // đảm bảo có id
        try {
          parsed.add(Movie.fromMap(raw));
        } catch (_) {}
      });
      movies = parsed;

      await _loadShowtimesForDay(days[selectedDay]);

      if (!mounted) return;
      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _loadShowtimesForDay(DateTime day) async {
    showtimesByMovie.clear();

    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final path = 'showtimes/${widget.cinema.id}/$key';
    final stSnap = await _db.child(path).get();

    if (stSnap.exists && stSnap.value is Map) {
      final data = Map<String, dynamic>.from(stSnap.value as Map);
      for (final entry in data.entries) {
        final movieId = entry.key.toString();
        final value = entry.value;
        final list = <Showtime>[];

        if (value is List) {
          for (final v in value) {
            final t = Showtime.fromAny(v);
            if (t != null) list.add(t);
          }
        } else if (value is Map) {
          for (final v in Map<String, dynamic>.from(value).values) {
            final t = Showtime.fromAny(v);
            if (t != null) list.add(t);
          }
        }
        showtimesByMovie[movieId] = list;
      }
      return;
    }

    // DEMO nếu chưa có dữ liệu DB
    final demo = const [
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

    for (final m in movies) {
      showtimesByMovie[m.id] = demo.map((t) {
        final options = [146, 162, 183]..shuffle();
        final total = options.first;
        return Showtime(
          start: TimeOfDay(hour: t[0], minute: t[1]),
          end: TimeOfDay(hour: t[2], minute: t[3]),
          available: (total * 0.85).floor(),
          total: total,
          format: '2D',
          subtitle: 'Phụ đề',
        );
      }).toList();
    }
  }

  final slotLabels = const [
    'Tất cả',
    '9:00 - 12:00',
    '12:00 - 15:00',
    '15:00 - 18:00',
    '18:00 - 21:00',
    '21:00 - 24:00',
  ];

  bool _inSlot(TimeOfDay t, int slot) {
    final m = t.hour * 60 + t.minute;
    switch (slot) {
      case 1:
        return m >= 540 && m < 720;
      case 2:
        return m >= 720 && m < 900;
      case 3:
        return m >= 900 && m < 1080;
      case 4:
        return m >= 1080 && m < 1260;
      case 5:
        return m >= 1260 && m < 1440;
      default:
        return true;
    }
  }

  String _weekday(DateTime d) =>
      ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][d.weekday % 7];

  @override
  Widget build(BuildContext context) {
    final date = days[selectedDay];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: Column(
          children: [
            // Header (gradient tối)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF11111A), Color(0xFF151521)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Color(0xFFEDEDED),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.cinema.name,
                      style: const TextStyle(
                        color: Color(0xFFEDEDED),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Icon(Icons.support_agent, color: Color(0xFFEDEDED)),
                  const SizedBox(width: 12),
                  const Icon(Icons.close, color: Color(0xFFEDEDED)),
                ],
              ),
            ),

            // Dải ngày
            SizedBox(
              height: 78,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final d = days[i];
                  final sel = i == selectedDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${d.day}/${d.month}',
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFFEDEDED),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            d == today ? 'H.nay' : _weekday(d),
                            style: TextStyle(
                              color: sel
                                  ? Colors.white70
                                  : const Color(0xFFB9B9C3),
                            ),
                          ),
                        ],
                      ),
                      selected: sel,
                      onSelected: (_) async {
                        setState(() {
                          selectedDay = i;
                          loading = true;
                        });
                        await _loadShowtimesForDay(days[selectedDay]);
                        if (!mounted) return;
                        setState(() => loading = false);
                      },
                      selectedColor: const Color(0xFF8B1E9B),
                      backgroundColor: const Color(0xFF151521),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: sel
                              ? const Color(0xFF8B1E9B)
                              : const Color(0xFF222230),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Lọc khung giờ
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: slotLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = i == selectedSlot;
                  return ChoiceChip(
                    label: Text(
                      slotLabels[i],
                      style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFFEDEDED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => selectedSlot = i),
                    selectedColor: const Color(0xFF8B1E9B),
                    backgroundColor: const Color(0xFF151521),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: sel
                            ? const Color(0xFF8B1E9B)
                            : const Color(0xFF222230),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  );
                },
              ),
            ),

            // Danh sách phim
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DANH SÁCH PHIM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB9B9C3),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),

            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B1E9B),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemBuilder: (_, i) {
                        final m = movies[i];
                        final all = (showtimesByMovie[m.id] ?? []);
                        final filtered = all
                            .where((s) => _inSlot(s.start, selectedSlot))
                            .toList();

                        return _MovieMoMoCard(
                          movie: m,
                          showtimes: filtered,
                          onTapShowtime: (s) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeatSelectionScreen(
                                  movie: m,
                                  selectedCinema: widget.cinema.name,
                                  selectedDate: DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    s.start.hour,
                                    s.start.minute,
                                  ),
                                  selectedTime: s.start,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemCount: movies.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==== Card giống MoMo ====
class _MovieMoMoCard extends StatelessWidget {
  final Movie movie;
  final List<Showtime> showtimes;
  final ValueChanged<Showtime> onTapShowtime;

  const _MovieMoMoCard({
    required this.movie,
    required this.showtimes,
    required this.onTapShowtime,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151521),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  movie.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEDEDED),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Chi tiết',
                  style: TextStyle(color: Color(0xFF8B1E9B)),
                ),
              ),
            ],
          ),
          Text(
            '${movie.genre} | ${movie.duration} phút',
            style: const TextStyle(color: Color(0xFFB9B9C3)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      width: 112,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 112,
                        height: 160,
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
                        Icons.movie,
                        size: 64,
                        color: Color(0xFFB9B9C3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.ondemand_video, color: Color(0xFF8B1E9B)),
                      SizedBox(width: 6),
                      Text(
                        'Trailer',
                        style: TextStyle(color: Color(0xFF8B1E9B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showtimes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C28),
                          border: Border.all(color: const Color(0xFF222230)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${showtimes.first.format} ${showtimes.first.subtitle}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (showtimes.isEmpty)
                      const Text(
                        'Không có suất chiếu trong khung giờ này.',
                        style: TextStyle(color: Color(0xFFB9B9C3)),
                      ),
                    if (showtimes.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, c) {
                          final itemWidth = (c.maxWidth - 12) / 2; // 2 cột
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: showtimes.map((s) {
                              return SizedBox(
                                width: itemWidth,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => onTapShowtime(s),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1C28),
                                      border: Border.all(
                                        color: const Color(0xFF222230),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: [
                                              Text(
                                                _fmt(s.start),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFEDEDED),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '~${_fmt(s.end)}',
                                                style: const TextStyle(
                                                  color: Color(0xFFB9B9C3),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Còn ${s.available}/${s.total}',
                                          style: const TextStyle(
                                            color: Color(0xFFB9B9C3),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
