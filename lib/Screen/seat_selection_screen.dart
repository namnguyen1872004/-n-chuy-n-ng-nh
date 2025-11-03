import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

/// ============================
///  MÀN HÌNH CHỌN GHẾ
///  - Hiển thị layout ghế đơn giản (grid)
///  - Thanh toán giả lập bằng QR (mã gồm movie|orderId|total)
///  - LƯU VÉ: tickets/{uid}/{orderId}  (đúng chuẩn để set rules theo uid)
/// ============================
class SeatSelectionScreen extends StatefulWidget {
  final Movie movie; // Phim đang đặt
  final DateTime selectedDate; // Ngày chiếu đã chọn từ BookingScreen
  final String selectedCinema; // Tên rạp đã chọn
  final TimeOfDay selectedTime; // Giờ chiếu đã chọn

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
  static const int _rows = 10; // 10 hàng: A..J
  static const int _cols = 8; // 8 cột: 1..8
  static const double _tile = 30.0; // kích thước ô ghế
  static const double _gap = 6.0; // khoảng cách giữa các ghế

  /// seats[r][c] = 'available' | 'vip' | 'booked'
  late final List<List<String>> seats; // ma trận trạng thái ghế

  /// Tập ghế đang chọn (mã như A1, B2…)
  final Set<String> selectedSeats = {}; // dùng Set để tránh trùng

  // Firebase helpers
  final _auth = FirebaseAuth.instance; // xác định user đang đăng nhập
  final _db = FirebaseDatabase.instance; // root của Realtime Database

  @override
  void initState() {
    super.initState();
    _initSeats(); // khởi tạo layout ghế demo
  }

  /// Tạo sơ đồ ghế demo:
  /// - Hàng đầu & hàng cuối là VIP
  /// - Một vài ghế bị khóa (booked) để mô phỏng
  void _initSeats() {
    // Tạo ma trận 'available'
    seats = List.generate(_rows, (_) => List.filled(_cols, 'available'));

    // VIP: hàng 0 (A) và hàng cuối (_rows - 1)
    for (int c = 0; c < _cols; c++) {
      seats[0][c] = 'vip';
      seats[_rows - 1][c] = 'vip';
    }

    // Đánh dấu một số ghế 'booked' (đã bán) để demo
    for (final id in ['A1', 'B2', 'C3', 'D4', 'E5']) {
      final r = id.codeUnitAt(0) - 65; // 'A' -> 65: chuyển A..J về 0..9
      final c = int.parse(id.substring(1)) - 1; // '1'..'8' về 0..7
      if (r >= 0 && r < _rows && c >= 0 && c < _cols) {
        seats[r][c] = 'booked';
      }
    }
  }

  /// Chọn / bỏ chọn ghế (không cho chọn ghế 'booked')
  void _toggleSeat(int row, int col) {
    if (seats[row][col] == 'booked') return; // khóa nếu ghế đã bán
    final seatId = '${String.fromCharCode(65 + row)}${col + 1}'; // ví dụ A1
    setState(() {
      // Nếu đã chọn -> bỏ chọn, chưa chọn -> thêm
      selectedSeats.contains(seatId)
          ? selectedSeats.remove(seatId)
          : selectedSeats.add(seatId);
    });
  }

  /// Tính tổng tiền (VIP 150k, thường 100k)
  int get totalPriceVND {
    int total = 0;
    for (final id in selectedSeats) {
      final r = id.codeUnitAt(0) - 65; // row
      final c = int.parse(id.substring(1)) - 1; // col
      total += (seats[r][c] == 'vip') ? 150000 : 100000;
    }
    return total;
  }

  /// Hiển thị dialog QR (QrImageView tạo ảnh QR ngay trên UI thread — đủ nhanh)
  void _showQrDialog() {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString(); // id đơn
    final total = totalPriceVND; // tổng tiền
    final qrData = 'PAY:${widget.movie.title}|$orderId|$total'; // payload

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
          mainAxisSize: MainAxisSize.min, // dialog cao vừa nội dung
          children: [
            // Vùng QR có nền trắng để app QR dễ nhận
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData, // nội dung mã QR
                version: QrVersions.auto, // để lib tự chọn version phù hợp
                size: 220, // kích thước ảnh QR
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Hiển thị số tiền đẹp dạng 100,000
            Text(
              '💰 ${NumberFormat('#,##0').format(total)} đ',
              style: const TextStyle(
                color: Colors.yellowAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Nút mô phỏng "đã thanh toán"
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Giả lập thanh toán thành công'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E9B),
              ),
              onPressed: () async {
                Navigator.pop(context); // đóng dialog QR
                await _saveTicket(orderId); // lưu vé vào DB
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
  /// - Lý do: dễ viết security rules kiểu "chỉ uid đó đọc/ghi tickets của mình"
  Future<void> _saveTicket(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) {
      // Chưa đăng nhập -> không thể lưu
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để lưu vé.')),
      );
      return;
    }

    try {
      final uid = user.uid;
      final dateIso = widget.selectedDate.toIso8601String(); // lưu dạng ISO
      final timeStr =
          '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}';

      // Ghi đúng chỗ: tickets/{uid}/{orderId}
      await _db.ref('tickets/$uid/$orderId').set({
        'orderId': orderId, // id đơn
        'userId': uid, // đối chiếu/migrate
        'movieTitle': widget.movie.title, // tên phim
        'cinema': widget.selectedCinema, // rạp
        'date': dateIso, // ngày (ISO)
        'time': timeStr, // giờ (HH:mm)
        'selectedSeats': selectedSeats.map((e) => e).toList(), // danh sách ghế
        'total': totalPriceVND, // tổng tiền
        'createdAt': DateTime.now().toIso8601String(), // thời điểm tạo
      });

      if (!mounted) return;
      // Thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Thanh toán thành công, vé đã được lưu!'),
          backgroundColor: Colors.green,
        ),
      );
      // Tuỳ ý: pop hoặc chuyển tới trang quản lý vé
    } catch (e) {
      // Bắt lỗi ghi DB (mạng/rules)
      debugPrint('🔥 Lỗi lưu vé: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được vé: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format ngày & giờ để hiển thị đẹp
    final date = DateFormat('dd/MM/yyyy').format(widget.selectedDate);
    final time =
        '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
        title: Text(
          widget.movie.title, // tiêu đề appbar là tên phim
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfo(date, time), // box thông tin rạp/ngày/giờ
          const SizedBox(height: 24),
          _buildScreen(), // thanh "MÀN HÌNH"
          const SizedBox(height: 20),
          _buildSeatGrid(), // lưới ghế
          const SizedBox(height: 16),
          _buildLegend(), // chú thích màu ghế
        ],
      ),
      bottomNavigationBar: _buildBottom(), // footer: tổng tiền + nút QR
    );
  }

  // ---------- UI con: thông tin suất chiếu ----------
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
        // Tên rạp
        Text(
          widget.selectedCinema,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        // Ngày giờ chiếu
        Text(
          'Ngày: $date  |  Giờ: $time',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  // ---------- UI con: thanh "MÀN HÌNH" ----------
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

  // ---------- UI con: lưới ghế ----------
  Widget _buildSeatGrid() => Center(
    child: SizedBox(
      width: _cols * (_tile + _gap), // tổng chiều rộng grid
      height: _rows * (_tile + _gap), // tổng chiều cao grid
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(), // không cuộn trong grid
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _cols, // số cột
          mainAxisSpacing: _gap, // khoảng cách dọc
          crossAxisSpacing: _gap, // khoảng cách ngang
        ),
        itemCount: _rows * _cols,
        itemBuilder: (_, i) {
          final r = i ~/ _cols; // hàng (0..rows-1)
          final c = i % _cols; // cột (0..cols-1)
          final id = '${String.fromCharCode(65 + r)}${c + 1}'; // A1..
          final status = seats[r][c]; // trạng thái ghế
          final selected = selectedSeats.contains(id);

          // Màu theo trạng thái + selected
          Color color;
          if (status == 'booked') {
            color = Colors.grey.shade800; // ghế đã bán: xám
          } else if (status == 'vip') {
            color = selected ? Colors.yellow : Colors.yellow.withOpacity(0.4);
          } else {
            color = selected
                ? const Color(0xFF8B1E9B) // thường + selected: tím
                : const Color(0xFF16213E); // thường + trống: xanh đậm
          }

          return InkWell(
            onTap: status == 'booked' ? null : () => _toggleSeat(r, c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150), // animate mượt
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24), // viền nhẹ
              ),
            ),
          );
        },
      ),
    ),
  );

  // ---------- UI con: chú thích trạng thái ghế ----------
  Widget _buildLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: const [
      _Legend('Trống', Color(0xFF16213E)),
      _Legend('Đã chọn', Color(0xFF8B1E9B)),
      _Legend('VIP', Colors.yellow),
      _Legend('Đã đặt', Color(0xFF2D2D44)),
    ],
  );

  // ---------- UI con: footer tổng tiền + nút thanh toán ----------
  Widget _buildBottom() {
    final loggedIn = _auth.currentUser != null; // đã đăng nhập chưa?
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF16213E),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nếu có ghế được chọn -> hiện danh sách + tổng
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
            // Nút thanh toán:
            //  - disable nếu chưa đăng nhập
            //  - disable nếu chưa chọn ghế
            //  - enable -> mở dialog QR
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

/// Chú thích ghế (legend: ô màu + nhãn)
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
