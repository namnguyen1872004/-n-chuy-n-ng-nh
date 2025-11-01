import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart'; // ✅ để dùng compute()

class TicketManagerScreen extends StatefulWidget {
  const TicketManagerScreen({super.key});

  @override
  State<TicketManagerScreen> createState() => _TicketManagerScreenState();
}

class _TicketManagerScreenState extends State<TicketManagerScreen> {
  final dbRef = FirebaseDatabase.instance.ref('tickets');
  List<Map<dynamic, dynamic>> tickets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  /// ✅ Lấy danh sách vé từ Firebase
  Future<void> _loadTickets() async {
    try {
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final list = data.entries.map((e) {
          final v = Map<dynamic, dynamic>.from(e.value);
          v['id'] = e.key;
          return v;
        }).toList();
        list.sort(
          (a, b) => (b['createdAt'] ?? '').toString().compareTo(
            (a['createdAt'] ?? '').toString(),
          ),
        );
        setState(() => tickets = list);
      }
    } catch (e) {
      debugPrint('🔥 Lỗi tải vé: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// ✅ Hiển thị QR của vé
  void _showTicketQr(Map<dynamic, dynamic> ticket) {
    final seatList = (ticket['selectedSeats'] as List?)?.join(', ') ?? 'N/A';
    final dateText = ticket['date'] ?? '';
    final formattedDate = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.tryParse(dateText) ?? DateTime.now());

    final qrData =
        'VÉ PHIM: ${ticket['movieTitle']}\nRạp: ${ticket['cinema']}\nGhế: $seatList\nGiờ: ${ticket['time']} | Ngày: $formattedDate\nMã đơn: ${ticket['orderId']}\nTổng tiền: ${NumberFormat('#,##0').format(ticket['total'])}đ';

    // ✅ Tạo mã QR trong isolate để không lag
    final qrFuture = compute((String text) {
      return QrPainter(
        data: text,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
    }, qrData);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mã QR vé của bạn',
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
                // ✅ QR mượt
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
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.lightBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${ticket['time'] ?? ''} | ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(ticket['date'] ?? '') ?? DateTime.now())}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
