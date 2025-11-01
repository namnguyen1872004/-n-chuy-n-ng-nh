import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

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

  late final List<List<String>> seats;
  final Set<String> selectedSeats = {};

  @override
  void initState() {
    super.initState();
    seats = List.generate(_rows, (_) => List.filled(_cols, 'available'));
    for (int c = 0; c < _cols; c++) {
      seats[0][c] = 'vip';
      seats[_rows - 1][c] = 'vip';
    }
    const booked = ['A1', 'B2', 'C3', 'D4', 'E5'];
    for (final id in booked) {
      final row = id.codeUnitAt(0) - 65;
      final col = int.parse(id.substring(1)) - 1;
      seats[row][col] = 'booked';
    }
  }

  void _toggleSeat(int row, int col) {
    final seatId = '${String.fromCharCode(65 + row)}${col + 1}';
    if (seats[row][col] == 'booked') return;
    setState(() {
      selectedSeats.contains(seatId)
          ? selectedSeats.remove(seatId)
          : selectedSeats.add(seatId);
    });
  }

  double _calculateTotal() {
    double total = 0;
    for (final id in selectedSeats) {
      final row = id.codeUnitAt(0) - 65;
      final col = int.parse(id.substring(1)) - 1;
      total += seats[row][col] == 'vip' ? 150000 : 100000;
    }
    return total;
  }

  // ✅ Tạo QR trong isolate để tránh lag
  Future<QrPainter> _generateQrPainter(String data) async {
    return await compute((String text) {
      return QrPainter(
        data: text,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
    }, data);
  }

  // ✅ Hiển thị QR mượt, không treo UI
  void _showQrDialog(double total) {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final qrData = 'PAY:${widget.movie.title}|$orderId|${total.toInt()}';
    final infoText =
        '''
Ngân hàng: BIDV
STK: 21510003732555
Tên: Nguyễn Hoài Nam
Số tiền: ${NumberFormat('#,##0').format(total)} đ
Nội dung: ${widget.movie.title} - $orderId
''';

    final qrFuture = _generateQrPainter(qrData);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quét mã QR thanh toán',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: FutureBuilder<QrPainter>(
          future: qrFuture,
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
                const SizedBox(height: 12),
                Text(
                  '💰 ${NumberFormat('#,##0').format(total)} đ',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã đơn: $orderId',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  infoText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _simulatePayment(orderId);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Giả lập quét thành công'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ✅ Lưu thông tin vé vào Firebase Realtime Database
  Future<void> _saveTicketToDatabase(String orderId, double total) async {
    try {
      final db = FirebaseDatabase.instance.ref();

      await db.child('tickets/$orderId').set({
        'orderId': orderId,
        'movieTitle': widget.movie.title,
        'cinema': widget.selectedCinema,
        'date': widget.selectedDate.toIso8601String(),
        'time':
            '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}',
        'selectedSeats': selectedSeats.toList(),
        'total': total,
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('🎟 Vé đã được lưu vào Firebase Realtime Database thành công');
    } catch (e) {
      debugPrint('🔥 Lỗi khi lưu vé vào Realtime Database: $e');
    }
  }

  Future<void> _simulatePayment(String orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);

    // 🟢 Lưu vé vào Firebase sau khi thanh toán thành công
    await _saveTicketToDatabase(orderId, _calculateTotal());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Thanh toán thành công! Vé đã được lưu vào Firebase!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
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
      ),
      bottomNavigationBar: _buildBottom(total),
    );
  }

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

  Widget _buildSeatGrid() {
    const tile = 30.0;
    const gap = 6.0;
    return Center(
      child: SizedBox(
        width: _cols * (tile + gap) + gap,
        height: _rows * (tile + gap) + gap,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
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
  }

  Widget _buildLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: const [
      _Legend('Trống', Color(0xFF16213E)),
      _Legend('Đã chọn', Color(0xFF8B1E9B)),
      _Legend('VIP', Colors.yellow),
      _Legend('Đã đặt', Color(0xFF2D2D44)),
    ],
  );

  Widget _buildBottom(double total) => Container(
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
              'Tổng: ${NumberFormat('#,##0').format(total)} đ',
              style: const TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: selectedSeats.isEmpty
                ? null
                : () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showQrDialog(total);
                    });
                  },
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
                  : 'Thanh toán QR Flutter',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
}

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
