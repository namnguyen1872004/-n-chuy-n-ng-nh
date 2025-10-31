// lib/models/seat_model.dart
import 'package:flutter/material.dart';

/// Model đại diện cho 1 ghế
class Seat {
  final String id; // ví dụ: A1
  String status; // available, booked, vip
  bool isSelected;

  Seat({required this.id, this.status = 'available', this.isSelected = false});

  double get price => status == 'vip' ? 150000 : 100000;
}

/// Model đại diện cho 1 hàng ghế
class SeatRow {
  final String rowLabel; // A, B, C,...
  final List<Seat> seats;

  SeatRow({required this.rowLabel, required this.seats});
}

/// Model thông tin thanh toán VNPay
class TicketPayment {
  final String orderInfo;
  final String cinema;
  final DateTime showDate;
  final TimeOfDay showTime;
  final List<String> seatIds;
  final double total;

  TicketPayment({
    required this.orderInfo,
    required this.cinema,
    required this.showDate,
    required this.showTime,
    required this.seatIds,
    required this.total,
  });
}
