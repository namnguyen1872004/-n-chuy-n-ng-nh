import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

/// ============================
///  MÀN HÌNH CHỌN GHẾ
///  - Hiển thị layout ghế đơn giản
///  - Thanh toán giả lập bằng QR
///  - LƯU VÉ: tickets/{uid}/{orderId}  (phù hợp rules)
/// ============================
class SeatSelectionScreen extends StatefulWidget {
  final Movie movie;
  final DateTime selectedDate;
  final String selectedCinema;
  final TimeOfDay selectedTime;

  const SeatSelectionScreen({
    super.key,
    required this.movie,
    required this.selectedDate,
    required this.selectedCinema,
    required this.selectedTime,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  // ---- Cấu hình layout ghế ----
  static const int _rows = 10;
  static const int _cols = 8;
  static const double _tile = 30.0;
  static const double _gap = 6.0;

  /// seats[r][c] = 'available' | 'vip' | 'booked'
  late final List<List<String>> seats;

  /// Tập ghế đang chọn (mã như A1, B2…)
  final Set<String> selectedSeats = {};

  // Firebase helpers
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _initSeats();
  }

  /// Tạo sơ đồ ghế demo:
  /// - Hàng đầu & cuối là VIP
  /// - Một vài ghế bị khóa (booked) để mô phỏng
  void _initSeats() {
    seats = List.generate(_rows, (_) => List.filled(_cols, 'available'));
    // VIP: hàng 0 và hàng cuối
    for (int c = 0; c < _cols; c++) {
      seats[0][c] = 'vip';
      seats[_rows - 1][c] = 'vip';
    }
    // Một số ghế booked
    for (final id in ['A1', 'B2', 'C3', 'D4', 'E5']) {
      final r = id.codeUnitAt(0) - 65;
      final c = int.parse(id.substring(1)) - 1;
      if (r >= 0 && r < _rows && c >= 0 && c < _cols) {
        seats[r][c] = 'booked';
      }
    }
  }

  /// Chọn / bỏ chọn ghế (trừ ghế booked)
  void _toggleSeat(int row, int col) {
    if (seats[row][col] == 'booked') return;
    final seatId = '${String.fromCharCode(65 + row)}${col + 1}';
    setState(() {
      selectedSeats.contains(seatId)
          ? selectedSeats.remove(seatId)
          : selectedSeats.add(seatId);
    });
  }

  /// Tính tổng tiền (VIP 150k, thường 100k)
  int get totalPriceVND {
    int total = 0;
    for (final id in selectedSeats) {
      final r = id.codeUnitAt(0) - 65;
      final c = int.parse(id.substring(1)) - 1;
      total += (seats[r][c] == 'vip') ? 150000 : 100000;
    }
    return total;
  }

  /// Hiển thị dialog QR (dùng QrImageView cho nhẹ máy)
  void _showQrDialog() {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final total = totalPriceVND;
    final qrData = 'PAY:${widget.movie.title}|$orderId|$total';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quét mã QR thanh toán',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Không dùng isolate: QrImageView là đủ nhanh, ít lỗi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💰 ${NumberFormat('#,##0').format(total)} đ',
              style: const TextStyle(
                color: Colors.yellowAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Giả lập thanh toán thành công'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E9B),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _saveTicket(orderId);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// LƯU VÉ VÀO Firebase THEO RULES:
  /// - Đường dẫn: tickets/{uid}/{orderId}
  /// - Field cần: userId, movieTitle, cinema, date, time, selectedSeats (List<String>), total (int)
  Future<void> _saveTicket(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để lưu vé.')),
      );
      return;
    }

    try {
      final uid = user.uid;
      final dateIso = widget.selectedDate.toIso8601String();
      final timeStr =
          '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}';

      // ✅ Ghi đúng chỗ: tickets/{uid}/{orderId}
      await _db.ref('tickets/$uid/$orderId').set({
        'orderId': orderId,
        'userId': uid, // giúp đối chiếu / migrate nếu cần
        'movieTitle': widget.movie.title,
        'cinema': widget.selectedCinema,
        'date': dateIso, // hoặc dùng key showDate nếu bạn đã chuyển code đọc
        'time': timeStr, // hoặc showTime: "HH:mm"
        'selectedSeats': selectedSeats.map((e) => e.toString()).toList(),
        'total': totalPriceVND, // int để định dạng tiền chuẩn
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Thanh toán thành công, vé đã được lưu!'),
          backgroundColor: Colors.green,
        ),
      );
      // (tuỳ chọn) pop về trước hoặc điều hướng TicketManager:
      // Navigator.pop(context);
    } catch (e) {
      debugPrint('🔥 Lỗi lưu vé: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được vé: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(widget.selectedDate);
    final time =
        '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
        title: Text(
          widget.movie.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfo(date, time),
          const SizedBox(height: 24),
          _buildScreen(),
          const SizedBox(height: 20),
          _buildSeatGrid(),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
      bottomNavigationBar: _buildBottom(),
    );
  }

  // ---------- UI con ----------
  Widget _buildInfo(String date, String time) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF8B1E9B).withOpacity(0.2),
          const Color(0xFF8B1E9B).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF8B1E9B).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.selectedCinema,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          'Ngày: $date  |  Giờ: $time',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildScreen() => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      width: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1E9B), Color(0xFF4A1E5A)],
        ),
      ),
      child: const Text(
        'MÀN HÌNH',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),
  );

  Widget _buildSeatGrid() => Center(
    child: SizedBox(
      width: _cols * (_tile + _gap),
      height: _rows * (_tile + _gap),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _cols,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
        ),
        itemCount: _rows * _cols,
        itemBuilder: (_, i) {
          final r = i ~/ _cols;
          final c = i % _cols;
          final id = '${String.fromCharCode(65 + r)}${c + 1}';
          final status = seats[r][c];
          final selected = selectedSeats.contains(id);

          Color color;
          if (status == 'booked') {
            color = Colors.grey.shade800;
          } else if (status == 'vip') {
            color = selected ? Colors.yellow : Colors.yellow.withOpacity(0.4);
          } else {
            color = selected
                ? const Color(0xFF8B1E9B)
                : const Color(0xFF16213E);
          }

          return InkWell(
            onTap: status == 'booked' ? null : () => _toggleSeat(r, c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: const [
      _Legend('Trống', Color(0xFF16213E)),
      _Legend('Đã chọn', Color(0xFF8B1E9B)),
      _Legend('VIP', Colors.yellow),
      _Legend('Đã đặt', Color(0xFF2D2D44)),
    ],
  );

  Widget _buildBottom() {
    final loggedIn = _auth.currentUser != null;
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF16213E),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedSeats.isNotEmpty) ...[
              Text(
                'Ghế: ${selectedSeats.join(", ")}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Tổng: ${NumberFormat('#,##0').format(totalPriceVND)} đ',
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton(
              onPressed: (!loggedIn || selectedSeats.isEmpty)
                  ? null
                  : _showQrDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E9B),
                disabledBackgroundColor: Colors.grey.shade700,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                !loggedIn
                    ? 'Vui lòng đăng nhập'
                    : (selectedSeats.isEmpty
                          ? 'Vui lòng chọn ghế'
                          : 'Thanh toán bằng QR'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chú thích ghế
class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}
