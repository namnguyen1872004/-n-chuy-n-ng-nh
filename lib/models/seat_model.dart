import 'package:flutter/material.dart';

/// -------------------------------
/// 🎟️ MODEL GHẾ (Seat)
/// -------------------------------
/// Đại diện cho 1 ghế trong rạp chiếu phim
/// - Mỗi ghế có id (ví dụ "A1")
/// - Có trạng thái: available / booked / vip
/// - Có thể được chọn (isSelected)
class Seat {
  /// Mã ghế (ví dụ: "A1", "B2", ...)
  final String id;

  /// Trạng thái ghế:
  /// - available: còn trống
  /// - booked: đã đặt
  /// - vip: ghế VIP (giá cao hơn)
  String status;

  /// Đang được người dùng chọn hay không
  bool isSelected;

  Seat({required this.id, this.status = 'available', this.isSelected = false});

  /// Giá của ghế — tính dựa theo trạng thái
  double get price => status == 'vip' ? 150000 : 100000;
}

/// -------------------------------
/// 🪑 MODEL HÀNG GHẾ (SeatRow)
/// -------------------------------
/// Đại diện cho 1 hàng ghế trong rạp (A, B, C, ...)
/// Gồm nhiều ghế con bên trong
class SeatRow {
  /// Nhãn hàng (A, B, C, ...)
  final String rowLabel;

  /// Danh sách các ghế trong hàng
  final List<Seat> seats;

  SeatRow({required this.rowLabel, required this.seats});
}

/// -------------------------------
/// 💳 MODEL THANH TOÁN VÉ (TicketPayment)
/// -------------------------------
/// Đại diện cho 1 giao dịch thanh toán vé phim.
/// Dùng cho việc lưu hoặc gửi lên Firebase.
class TicketPayment {
  /// Mã đơn hàng / mô tả đơn hàng (ví dụ: "Thanh toan phim ABC - CGV")
  final String orderInfo;

  /// Tên rạp chiếu phim
  final String cinema;

  /// Ngày chiếu phim
  final DateTime showDate;

  /// Giờ chiếu phim
  final TimeOfDay showTime;

  /// Danh sách mã ghế (ví dụ: ["A1", "A2", "B3"])
  final List<String> seatIds;

  /// Tổng số tiền thanh toán
  final double total;

  /// Trạng thái thanh toán (pending / success / failed)
  String status;

  TicketPayment({
    required this.orderInfo,
    required this.cinema,
    required this.showDate,
    required this.showTime,
    required this.seatIds,
    required this.total,
    this.status = "pending",
  });

  /// Chuyển model thành JSON để lưu vào Firebase
  Map<String, dynamic> toJson() => {
    'orderInfo': orderInfo,
    'cinema': cinema,
    'showDate': showDate.toIso8601String(),
    'showTime': '${showTime.hour}:${showTime.minute}',
    'seatIds': seatIds,
    'total': total,
    'status': status,
  };

  /// Tạo đối tượng từ JSON (nếu cần lấy về từ Firebase)
  factory TicketPayment.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['showTime'] as String).split(':');
    return TicketPayment(
      orderInfo: json['orderInfo'] ?? '',
      cinema: json['cinema'] ?? '',
      showDate: DateTime.parse(json['showDate']),
      showTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      seatIds: List<String>.from(json['seatIds'] ?? []),
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
    );
  }
}
