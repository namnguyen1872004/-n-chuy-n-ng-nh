import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/cinema_model.dart';
import '../models/movie.dart';
import '../models/showtime_model.dart';

class ShowtimesScreen extends StatefulWidget {
  final Cinema selectedCinema;
  final Movie selectedMovie;
  final DateTime selectedDate;
  final TimeOfDay? selectedTime; // có thể null khi mở lần đầu

  const ShowtimesScreen({
    super.key,
    required this.selectedCinema,
    required this.selectedMovie,
    required this.selectedDate,
    this.selectedTime,
  });

  @override
  State<ShowtimesScreen> createState() => _ShowtimesScreenState();
}

class _ShowtimesScreenState extends State<ShowtimesScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Showtime> showtimes = [];
  bool isLoading = true;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    selectedTime = widget.selectedTime;
    fetchShowtimes();
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> fetchShowtimes() async {
    try {
      final snap = await _database.child('showtimes').get();
      final val = snap.value;

      final Map<String, dynamic> map = {};
      if (val is Map) {
        val.forEach((k, v) => map[k.toString()] = v);
      } else if (val is List) {
        for (int i = 0; i < val.length; i++) {
          map[i.toString()] = val[i];
        }
      }

      final parsed = <Showtime>[];
      map.forEach((id, data) {
        if (data is! Map) return;
        try {
          parsed.add(Showtime.fromMap(Map<String, dynamic>.from(data)));
        } catch (e) {
          debugPrint('Error parsing showtime $id: $e');
        }
      });

      // Lọc theo rạp + phim
      final byCinemaMovie = parsed.where(
        (s) =>
            s.cinemaId == widget.selectedCinema.id &&
            s.movieId == widget.selectedMovie.id,
      );

      // Lọc đúng ngày + còn sau "bây giờ" (nếu là hôm nay)
      final now = DateTime.now();
      final filtered =
          byCinemaMovie.where((s) {
            final sameDay = _isSameDate(s.date, widget.selectedDate);
            if (!sameDay) return false;

            // Nếu ngày là hôm nay, chỉ giữ giờ > hiện tại
            if (_isSameDate(widget.selectedDate, now)) {
              final st = DateTime(
                s.date.year,
                s.date.month,
                s.date.day,
                s.time.hour,
                s.time.minute,
              );
              return st.isAfter(now);
            }
            return true;
          }).toList()..sort((a, b) {
            final am = a.time.hour * 60 + a.time.minute;
            final bm = b.time.hour * 60 + b.time.minute;
            return am.compareTo(bm);
          });

      if (!mounted) return;
      setState(() {
        showtimes = filtered;
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

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn giờ - ${widget.selectedMovie.title}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rạp: ${widget.selectedCinema.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngày: ${_fmtDate(widget.selectedDate)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  if (showtimes.isEmpty)
                    Text(
                      _isSameDate(widget.selectedDate, DateTime.now())
                          ? 'Không có suất chiếu sau ${now.format(context)}.'
                          : 'Không có suất chiếu cho ngày này.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),

                  if (showtimes.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: showtimes.map((st) {
                        final bool isSelected = selectedTime == st.time;
                        return ElevatedButton(
                          onPressed: () =>
                              setState(() => selectedTime = st.time),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? Colors.pink.shade50
                                : null,
                            foregroundColor: isSelected ? Colors.black87 : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            '${st.time.format(context)} • ${st.room ?? 'Phòng'}',
                          ),
                        );
                      }).toList(),
                    ),

                  const Spacer(),

                  // Confirm
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedTime == null
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'selectedCinema': widget.selectedCinema,
                                'selectedMovie': widget.selectedMovie,
                                'selectedDate': widget.selectedDate,
                                'selectedTime': selectedTime, // TimeOfDay
                              });
                            },
                      child: const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
