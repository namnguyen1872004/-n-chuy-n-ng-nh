import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:vnpay_flutter/vnpay_flutter.dart';
import '../models/movie.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Movie movie;
  final DateTime selectedDate;
  final String selectedCinema;
  final TimeOfDay selectedTime; // ✅ dùng TimeOfDay

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
  // ================== VNPay SANDBOX CONFIG ==================
  static const String _vnpBaseUrl =
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  static const String _vnpTmnCode = 'P796156C';
  static const String _vnpHashSecret = 'FM0JPA4DMKKM1Z3ATT4MMNOJI15CF2FJ';
  static const String _vnpReturnUrl = 'https://sandbox.vnpayment.vn/return';

  // ================== DATA GHẾ ==================
  final List<List<String>> seats = List.generate(
    10,
    (row) => List.generate(8, (col) => 'available'),
  );
  final Set<String> selectedSeats = <String>{};

  final Map<String, String> bookedSeats = {
    'A1': 'booked',
    'B2': 'booked',
    'C3': 'booked',
    'D4': 'booked',
    'E5': 'booked',
  };

  @override
  void initState() {
    super.initState();
    for (var seat in bookedSeats.keys) {
      final row = seat[0];
      final col = int.parse(seat.substring(1)) - 1;
      if (row.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
          row.codeUnitAt(0) <= 'J'.codeUnitAt(0) &&
          col >= 0 &&
          col < 8) {
        seats[row.codeUnitAt(0) - 'A'.codeUnitAt(0)][col] = bookedSeats[seat]!;
      }
    }
    for (int col = 0; col < 8; col++) {
      seats[0][col] = 'vip';
      seats[9][col] = 'vip';
    }
  }

  void toggleSeat(String seatId) {
    setState(() {
      if (seats[seatId[0].codeUnitAt(0) -
              'A'.codeUnitAt(0)][int.parse(seatId.substring(1)) - 1] !=
          'booked') {
        if (selectedSeats.contains(seatId)) {
          selectedSeats.remove(seatId);
        } else {
          selectedSeats.add(seatId);
        }
      }
    });
  }

  double calculateTotal() {
    double total = 0;
    for (var seatId in selectedSeats) {
      final row = seatId[0];
      final col = int.parse(seatId.substring(1)) - 1;
      final seatStatus = seats[row.codeUnitAt(0) - 'A'.codeUnitAt(0)][col];
      total += (seatStatus == 'vip') ? 150000 : 100000;
    }
    return total;
  }

  // ================== Helpers ==================
  String _fmtVnpDate(DateTime dt) => DateFormat('yyyyMMddHHmmss').format(dt);
  String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Encode kiểu PHP urlencode: khoảng trắng -> '+'
  String _phpUrlEncode(String input) {
    return Uri.encodeQueryComponent(input).replaceAll('%20', '+');
  }

  /// Tạo chữ ký HMAC-SHA512 từ chuỗi RAW "key=value&key=value..."
  String _signRaw(Map<String, String> params, String secret) {
    final keys = params.keys.toList()..sort();
    final raw = keys.map((k) => '$k=${params[k]}').join('&'); // RAW
    final hmacSha512 = Hmac(sha512, utf8.encode(secret));
    return hmacSha512.convert(utf8.encode(raw)).toString();
  }

  /// Build URL thanh toán
  String _buildVnpPaymentUrl({
    required String orderInfo,
    required String ipAddr,
    required int amountTimes100,
    required DateTime create,
    required DateTime expire,
  }) {
    final txnRef = DateTime.now().millisecondsSinceEpoch.toString();

    final params = <String, String>{
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': _vnpTmnCode,
      'vnp_Amount': amountTimes100.toString(),
      'vnp_CurrCode': 'VND',
      'vnp_TxnRef': txnRef,
      'vnp_OrderInfo': orderInfo, // RAW khi ký
      'vnp_OrderType': 'other',
      'vnp_Locale': 'vn',
      'vnp_ReturnUrl': _vnpReturnUrl,
      'vnp_IpAddr': ipAddr,
      'vnp_CreateDate': _fmtVnpDate(create),
      'vnp_ExpireDate': _fmtVnpDate(expire),
    };

    // 1) Ký trên RAW
    final secureHash = _signRaw(params, _vnpHashSecret);

    // 2) Build query có encode
    final keys = params.keys.toList()..sort();
    final query = keys
        .map((k) => '${_phpUrlEncode(k)}=${_phpUrlEncode(params[k] ?? '')}')
        .join('&');

    // 3) Append hash
    final url =
        '$_vnpBaseUrl?$query&vnp_SecureHashType=HmacSHA512&vnp_SecureHash=$secureHash';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final total = calculateTotal();
    final showDate =
        '${widget.selectedDate.day.toString().padLeft(2, '0')}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}';
    final showTime = _fmtTimeOfDay(widget.selectedTime); // ✅ format TimeOfDay

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // ===== Info =====
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B1E9B).withOpacity(0.2),
                            const Color(0xFF8B1E9B).withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF8B1E9B).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.selectedCinema,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      showDate,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      showTime, // ✅ hiển thị giờ
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ===== SCREEN =====
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF8B1E9B).withOpacity(0.6),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0x4D8B1E9B), Color(0x1A8B1E9B)],
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(80),
                                bottomRight: Radius.circular(80),
                              ),
                            ),
                            child: const Text(
                              'MÀN HÌNH',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ===== SEATS 10x8 =====
                    Center(
                      child: Column(
                        children: List.generate(10, (rowIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    String.fromCharCode(
                                      'A'.codeUnitAt(0) + rowIndex,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...List.generate(8, (colIndex) {
                                  final seatId =
                                      '${String.fromCharCode('A'.codeUnitAt(0) + rowIndex)}${colIndex + 1}';
                                  final seatStatus = seats[rowIndex][colIndex];
                                  final isSelected = selectedSeats.contains(
                                    seatId,
                                  );

                                  Color seatColor;
                                  Color borderColor;
                                  IconData seatIcon;

                                  if (seatStatus == 'booked') {
                                    seatColor = const Color(0xFF2d2d44);
                                    borderColor = const Color(0xFF2d2d44);
                                    seatIcon = Icons.event_seat;
                                  } else if (seatStatus == 'vip') {
                                    if (isSelected) {
                                      seatColor = const Color(0xFFFFB800);
                                      borderColor = const Color(0xFFFFD700);
                                      seatIcon = Icons.weekend;
                                    } else {
                                      seatColor = const Color(
                                        0xFFFFB800,
                                      ).withOpacity(0.3);
                                      borderColor = const Color(
                                        0xFFFFB800,
                                      ).withOpacity(0.5);
                                      seatIcon = Icons.weekend;
                                    }
                                  } else {
                                    if (isSelected) {
                                      seatColor = const Color(0xFF8B1E9B);
                                      borderColor = const Color(0xFFB24FBF);
                                      seatIcon = Icons.event_seat;
                                    } else {
                                      seatColor = const Color(
                                        0xFF16213e,
                                      ).withOpacity(0.8);
                                      borderColor = const Color(
                                        0xFF0f3460,
                                      ).withOpacity(0.5);
                                      seatIcon = Icons.event_seat;
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => toggleSeat(seatId),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: seatColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: borderColor,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: seatStatus == 'vip'
                                                        ? const Color(
                                                            0xFFFFB800,
                                                          ).withOpacity(0.4)
                                                        : const Color(
                                                            0xFF8B1E9B,
                                                          ).withOpacity(0.4),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            seatIcon,
                                            color: seatStatus == 'booked'
                                                ? Colors.white24
                                                : Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ===== Legend =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213e).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem(
                            color: const Color(0xFF16213e).withOpacity(0.8),
                            borderColor: const Color(
                              0xFF0f3460,
                            ).withOpacity(0.5),
                            label: 'Trống',
                          ),
                          _buildLegendItem(
                            color: const Color(0xFF8B1E9B),
                            borderColor: const Color(0xFFB24FBF),
                            label: 'Đã chọn',
                          ),
                          _buildLegendItem(
                            color: const Color(0xFF2d2d44),
                            borderColor: const Color(0xFF2d2d44),
                            label: 'Đã đặt',
                          ),
                          _buildLegendItem(
                            color: const Color(0xFFFFB800).withOpacity(0.3),
                            borderColor: const Color(
                              0xFFFFB800,
                            ).withOpacity(0.5),
                            label: 'VIP',
                            icon: Icons.star,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== Bottom pay =====
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF16213e),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (selectedSeats.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ghế: ${selectedSeats.join(', ')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedSeats.length} ghế',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Tổng tiền',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')} đ',
                              style: const TextStyle(
                                color: Color(0xFFFFB800),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: selectedSeats.isNotEmpty
                        ? () async {
                            final now = DateTime.now().toLocal();
                            final int amountTimes100 = (total.round()) * 100;

                            final paymentUrl = _buildVnpPaymentUrl(
                              orderInfo:
                                  'Thanh toan ${widget.movie.title} - ${widget.selectedCinema} - $showDate $showTime - Ghe: ${selectedSeats.join(', ')}',
                              ipAddr: '192.168.10.10',
                              amountTimes100: amountTimes100,
                              create: now,
                              expire: now.add(const Duration(minutes: 15)),
                            );

                            await VNPAYFlutter.instance.show(
                              context: context,
                              paymentUrl: paymentUrl,
                              onPaymentSuccess: (params) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Thanh toán thành công! Mã đơn hàng: ${params['vnp_TxnRef']}',
                                    ),
                                    backgroundColor: const Color(0xFF8B1E9B),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                Navigator.popUntil(
                                  context,
                                  (route) => route.isFirst,
                                );
                              },
                              onPaymentError: (params) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Thanh toán thất bại: ${params['vnp_ResponseCode']} - ${params['vnp_Message'] ?? 'Không có thông tin'}',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              onWebPaymentComplete: () {
                                // ignore: avoid_print
                                print('Thanh toán trên Web hoàn tất');
                              },
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E9B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2d2d44),
                      disabledForegroundColor: Colors.white38,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      selectedSeats.isEmpty
                          ? 'Vui lòng chọn ghế'
                          : 'Thanh toán VNPay',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color borderColor,
    required String label,
    IconData? icon,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: icon != null
              ? Icon(icon, size: 12, color: const Color(0xFFFFB800))
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
