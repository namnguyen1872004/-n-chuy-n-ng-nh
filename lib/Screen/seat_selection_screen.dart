import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

/// ============================
///   MÀN HÌNH CHỌN GHẾ
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
  static const int _rows = 10;
  static const int _cols = 8;
  static const double _tile = 30.0;
  static const double _gap = 6.0;

  late final List<List<String>> seats;
  final Set<String> selectedSeats = {};

  @override
  void initState() {
    super.initState();
    _initSeats();
  }

  /// 🔹 Khởi tạo sơ đồ ghế
  void _initSeats() {
    seats = List.generate(_rows, (_) => List.filled(_cols, 'available'));
    for (int c = 0; c < _cols; c++) {
      seats[0][c] = 'vip';
      seats[_rows - 1][c] = 'vip';
    }
    for (final id in ['A1', 'B2', 'C3', 'D4', 'E5']) {
      final r = id.codeUnitAt(0) - 65;
      final c = int.parse(id.substring(1)) - 1;
      seats[r][c] = 'booked';
    }
  }

  /// 🔹 Đổi trạng thái chọn ghế
  void _toggleSeat(int row, int col) {
    final seatId = '${String.fromCharCode(65 + row)}${col + 1}';
    if (seats[row][col] == 'booked') return;
    setState(() {
      selectedSeats.contains(seatId)
          ? selectedSeats.remove(seatId)
          : selectedSeats.add(seatId);
    });
  }

  /// 🔹 Tính tổng tiền
  double get totalPrice {
    double total = 0;
    for (final id in selectedSeats) {
      final r = id.codeUnitAt(0) - 65;
      final c = int.parse(id.substring(1)) - 1;
      total += seats[r][c] == 'vip' ? 150000 : 100000;
    }
    return total;
  }

  /// 🔹 Sinh mã QR nhanh, tránh lag
  Future<QrPainter> _generateQr(String data) async {
    return await compute((String text) {
      return QrPainter(
        data: text,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
      );
    }, data);
  }

  /// 🔹 Hiển thị dialog QR
  void _showQrDialog() {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final total = totalPrice;
    final qrData = 'PAY:${widget.movie.title}|$orderId|${total.toInt()}';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quét mã QR thanh toán',
          style: TextStyle(color: Colors.white),
        ),
        content: FutureBuilder<QrPainter>(
          future: _generateQr(qrData),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: snapshot.data!,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '💰 ${NumberFormat('#,##0').format(total)} đ',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Giả lập thanh toán thành công'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _saveTicket(orderId);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Lưu vé vào Firebase
  Future<void> _saveTicket(String orderId) async {
    try {
      await FirebaseDatabase.instance.ref('tickets/$orderId').set({
        'orderId': orderId,
        'movieTitle': widget.movie.title,
        'cinema': widget.selectedCinema,
        'date': widget.selectedDate.toIso8601String(),
        'time':
            '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}',
        'selectedSeats': selectedSeats.toList(),
        'total': totalPrice,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Thanh toán thành công, vé đã được lưu!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('🔥 Lỗi lưu vé: $e');
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

  /// 🔹 Thông tin suất chiếu
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

  /// 🔹 Màn hình rạp
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

  /// 🔹 Lưới ghế
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

  /// 🔹 Chú thích màu ghế
  Widget _buildLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: const [
      _Legend('Trống', Color(0xFF16213E)),
      _Legend('Đã chọn', Color(0xFF8B1E9B)),
      _Legend('VIP', Colors.yellow),
      _Legend('Đã đặt', Color(0xFF2D2D44)),
    ],
  );

  /// 🔹 Thanh thanh toán
  Widget _buildBottom() => Container(
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
              'Tổng: ${NumberFormat('#,##0').format(totalPrice)} đ',
              style: const TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: selectedSeats.isEmpty ? null : () => _showQrDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1E9B),
              disabledBackgroundColor: Colors.grey.shade700,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              selectedSeats.isEmpty
                  ? 'Vui lòng chọn ghế'
                  : 'Thanh toán bằng QR',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 🔹 Widget chú thích ghế
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
