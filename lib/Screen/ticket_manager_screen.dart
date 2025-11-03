import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart'; // ✅ để dùng compute() chạy QR painter ở isolate, tránh giật

class TicketManagerScreen extends StatefulWidget {
  const TicketManagerScreen({super.key});

  @override
  State<TicketManagerScreen> createState() => _TicketManagerScreenState();
}

class _TicketManagerScreenState extends State<TicketManagerScreen> {
  // Trỏ tới node "tickets" trên Realtime Database.
  // LƯU Ý: Hiện đang đọc thẳng /tickets (tất cả người dùng).
  // Nếu rules chỉ cho phép đọc vé của chính user → bạn nên đổi thành tickets/{uid hiện tại}.
  final dbRef = FirebaseDatabase.instance.ref('tickets');

  // Danh sách vé đã load (mỗi vé là 1 Map động cho linh hoạt schema)
  List<Map<dynamic, dynamic>> tickets = [];

  // Cờ hiển thị vòng tròn loading
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets(); // Khi vào màn hình → tải danh sách vé 1 lần
  }

  /// ✅ Lấy danh sách vé từ Firebase
  Future<void> _loadTickets() async {
    try {
      // Gọi GET 1 lần toàn bộ nhánh /tickets
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        // Kỳ vọng dữ liệu dạng Map (key = orderId hoặc uid tuỳ cấu trúc)
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Chuyển về List<Map> để dễ ListView.builder
        final list = data.entries.map((e) {
          final v = Map<dynamic, dynamic>.from(e.value); // sao chép Map con
          v['id'] = e.key; // thêm id để debug/trace
          return v;
        }).toList();

        // Sắp xếp giảm dần theo createdAt (mới nhất lên đầu)
        list.sort(
          (a, b) => (b['createdAt'] ?? '').toString().compareTo(
            (a['createdAt'] ?? '').toString(),
          ),
        );

        setState(() => tickets = list);
      }
    } catch (e) {
      // Bắt lỗi network / permission / parse
      debugPrint('🔥 Lỗi tải vé: $e');
    } finally {
      setState(
        () => isLoading = false,
      ); // Tắt loading bất kể thành công hay lỗi
    }
  }

  /// ✅ Hiển thị QR của vé
  /// - Ghép chuỗi có đủ thông tin (phim/rap/ghe/ngay/gio/ma don/tong tien)
  /// - Render QR bằng QrPainter ở isolate (compute) để UI không bị khựng
  void _showTicketQr(Map<dynamic, dynamic> ticket) {
    // Ghế có thể là List<String> → join lại để hiển thị
    final seatList = (ticket['selectedSeats'] as List?)?.join(', ') ?? 'N/A';

    // Chuẩn hoá ngày chiếu (ISO) → dd/MM/yyyy
    final dateText = ticket['date'] ?? '';
    final formattedDate = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.tryParse(dateText) ?? DateTime.now());

    // Nội dung sẽ encode vào QR (thuần text để máy quét đọc)
    final qrData =
        'VÉ PHIM: ${ticket['movieTitle']}\n'
        'Rạp: ${ticket['cinema']}\n'
        'Ghế: $seatList\n'
        'Giờ: ${ticket['time']} | Ngày: $formattedDate\n'
        'Mã đơn: ${ticket['orderId']}\n'
        'Tổng tiền: ${NumberFormat('#,##0').format(ticket['total'])}đ';

    // ✅ Tạo QrPainter trong isolate bằng compute để không block main thread
    // compute nhận 1 function top-level/closure biệt lập + tham số; trả về QrPainter
    final qrFuture = compute((String text) {
      return QrPainter(
        data: text,
        version: QrVersions.auto, // tự chọn phiên bản phù hợp độ dài text
        color: const Color(0xFF000000), // màu nét QR
        emptyColor: const Color(0xFFFFFFFF), // màu nền QR
      );
    }, qrData);

    // Mở dialog hiển thị QR
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mã QR vé của bạn',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        // Dùng FutureBuilder để chờ QrPainter render ở isolate xong
        content: FutureBuilder<QrPainter>(
          future: qrFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              // Trong lúc chờ → spinner nhỏ
              return const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            // Khi đã có QrPainter → vẽ vào CustomPaint
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Khung trắng bọc QR giúp độ tương phản tốt hơn khi quét
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, // nền trắng
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    size: const Size(220, 220), // kích thước QR
                    painter: snapshot.data!, // QrPainter đã sinh
                  ),
                ),
                const SizedBox(height: 12),

                // Tiêu đề: tên phim
                Text(
                  ticket['movieTitle'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // 🪑 Ghế
                Text(
                  'Ghế: $seatList',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),

                // 📅 Ngày chiếu
                Text(
                  'Ngày chiếu: $formattedDate',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),

                // 🔢 Mã đơn
                Text(
                  'Mã đơn: ${ticket['orderId']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),

                // 💰 Tổng tiền
                Text(
                  'Tổng: ${NumberFormat('#,##0').format(ticket['total'])} đ',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Nút đóng dialog
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Đóng'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Quản lý vé',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      // Phần thân: 3 trạng thái → loading / rỗng / có dữ liệu
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            )
          : tickets.isEmpty
          ? const Center(
              child: Text(
                'Chưa có vé nào được đặt',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];

                // Thẻ hiển thị từng vé
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      ticket['movieTitle'] ?? 'Không rõ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),

                        // Dòng rạp chiếu
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ticket['cinema'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Dòng ghế đã đặt
                        Row(
                          children: [
                            const Icon(
                              Icons.event_seat,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ghế: ${(ticket['selectedSeats'] as List?)?.join(", ") ?? "?"}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Dòng giờ & ngày chiếu
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.lightBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              // Format lại ngày (ISO) → dd/MM/yyyy, nếu lỗi thì dùng now()
                              '${ticket['time'] ?? ''} | ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(ticket['date'] ?? '') ?? DateTime.now())}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Nút xem mã QR (mở dialog QR)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showTicketQr(ticket),
                            child: const Text(
                              'Xem mã QR',
                              style: TextStyle(
                                color: Color(0xFF8B1E9B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
