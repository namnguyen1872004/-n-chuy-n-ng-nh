import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/snack_model.dart';

class SnackScreen extends StatefulWidget {
  const SnackScreen({super.key});

  @override
  State<SnackScreen> createState() => _SnackScreenState();
}

class _SnackScreenState extends State<SnackScreen> {
  String selectedCinemaId = ''; // id rạp đang chọn để load snack theo rạp
  String filter = 'Tất cả'; // (để mở rộng: lọc loại snack)
  String searchQuery = ''; // (để mở rộng: tìm kiếm snack)
  final DatabaseReference _database = FirebaseDatabase.instance
      .ref(); // root DB

  final List<Snack> cartItems = []; // giỏ hàng hiện tại
  int cartCount = 0; // hiển thị badge số lượng trên icon cart

  // ================== Helpers: Giá & Ảnh ==================

  /// Chuẩn hoá giá về **VND** (đồng):
  /// - Nếu số < 1000 (65 / "65") coi là **ngàn** → 65 * 1000 = 65.000đ
  /// - Nếu số >= 1000 coi là đồng → giữ nguyên.
  int _toVND(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) {
      final v = raw.toDouble();
      return v < 1000 ? (v * 1000).round() : v.round();
    }
    if (raw is String) {
      // Loại bỏ ký tự không phải số/dấu chấm (đề phòng dữ liệu "65k", "65.000")
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleaned.isEmpty) return 0;
      final v = double.tryParse(cleaned) ?? 0;
      return v < 1000 ? (v * 1000).round() : v.round();
    }
    return 0;
  }

  /// Lấy URL ảnh từ nhiều key phổ biến trong Firebase để chống lệch schema
  String _getImageUrl(Map<String, dynamic> m) {
    final keys = ['imageUrl', 'imageURL', 'image', 'img'];
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return ''; // fallback rỗng -> hiển thị placeholder
  }

  /// Format tiền VND có dấu phẩy ngăn cách + hậu tố "đ"
  String _fmtCurrency(num vnd) => '${NumberFormat("#,##0").format(vnd)} đ';

  // ================== Cart ==================

  /// Thêm 1 món snack vào giỏ + tăng badge
  void addToCart(Snack snack) {
    setState(() {
      cartItems.add(snack);
      cartCount++;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã thêm ${snack.name} vào giỏ')));
  }

  /// Tổng tiền hiện tại của giỏ (đơn vị: đồng)
  double get totalPrice => cartItems.fold(0, (sum, item) => sum + (item.price));

  /// Mở dialog giỏ hàng: liệt kê món + tổng tiền + nút thanh toán QR
  void _openCartDialog() {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Giỏ hàng trống')));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF151521),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Giỏ hàng của bạn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // fit nội dung
            children: [
              // Liệt kê từng item trong giỏ
              ...cartItems.map(
                (snack) => ListTile(
                  dense: true,
                  title: Text(
                    snack.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _fmtCurrency(snack.price),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const Divider(color: Colors.white30),
              // Hàng tổng tiền
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cộng:',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    _fmtCurrency(totalPrice),
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Nút thanh toán -> đóng dialog -> mở bottom sheet QR
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    _showQrSheet,
                  );
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('Thanh toán QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E9B),
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiện QR thanh toán ở bottom sheet (mã giả lập chứa: mã đơn + danh sách món + tổng tiền)
  void _showQrSheet() {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString(); // mã đơn
    final snackNames = cartItems.map((e) => e.name).join(', '); // liệt kê món
    final total = _fmtCurrency(totalPrice); // tiền đã format

    final qrData =
        'Thanh toán bắp nước\nMã đơn: $orderId\nMón: $snackNames\nTổng tiền: $total';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // chỉ cao vừa QR + nút
          children: [
            const Text(
              'Mã QR Thanh Toán',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            // QR để người dùng quét (demo)
            Container(
              color: Colors.white, // nền trắng giúp máy quét dễ nhận
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Hiển thị tổng tiền + mã đơn
            Text(
              total,
              style: const TextStyle(
                color: Colors.yellowAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mã đơn: $orderId',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            // Nút xác nhận thanh toán (giả lập) -> clear giỏ
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccess(orderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E9B),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Xác nhận thanh toán'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Sau khi "thanh toán" thành công (giả lập) -> hiển thị toast + reset giỏ
  void _showSuccess(String orderId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Thanh toán thành công! Mã đơn: $orderId'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      cartItems.clear();
      cartCount = 0;
    });
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Bắp Nước',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          // Icon giỏ hàng + badge số lượng
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Color(0xFFEDEDED)),
                onPressed: _openCartDialog,
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Dropdown chọn rạp từ Firebase (stream realtime) ---
          StreamBuilder<DatabaseEvent>(
            stream: _database
                .child('cinemas')
                .onValue, // lắng nghe mọi thay đổi
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Lỗi: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFEDEDED)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                // Chưa có dữ liệu rạp
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Không có dữ liệu rạp!',
                    style: TextStyle(color: Color(0xFFB9B9C3)),
                  ),
                );
              }

              // Chuẩn hoá snapshot (Map hoặc List) về Map<String, dynamic>
              final rawData = snapshot.data!.snapshot.value;
              Map<String, dynamic> cinemasMap = {};
              if (rawData is Map) {
                cinemasMap = Map<String, dynamic>.from(rawData);
              } else if (rawData is List) {
                for (int i = 0; i < rawData.length; i++) {
                  if (rawData[i] != null) {
                    cinemasMap[i.toString()] = Map<String, dynamic>.from(
                      rawData[i],
                    );
                  }
                }
              }

              // Nếu chưa chọn rạp -> chọn rạp đầu tiên
              if (selectedCinemaId.isEmpty && cinemasMap.isNotEmpty) {
                selectedCinemaId = cinemasMap.keys.first;
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222230)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: selectedCinemaId.isEmpty ? null : selectedCinemaId,
                    hint: const Text(
                      'Chọn rạp',
                      style: TextStyle(color: Color(0xFFB9B9C3)),
                    ),
                    items: cinemasMap.entries.map((entry) {
                      final data = Map<String, dynamic>.from(entry.value);
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          (data['name'] ?? 'Không có tên').toString(),
                          style: const TextStyle(color: Color(0xFFEDEDED)),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() => selectedCinemaId = newValue ?? '');
                    },
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(
                      color: Color(0xFFEDEDED),
                      fontSize: 16,
                    ),
                    dropdownColor: const Color(0xFF151521),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                ),
              );
            },
          ),

          // --- Danh sách snack theo rạp đã chọn ---
          Expanded(
            child: selectedCinemaId.isEmpty
                // Nếu chưa chọn rạp: nhắc chọn
                ? const Center(
                    child: Text(
                      'Hãy chọn một rạp để xem bắp nước',
                      style: TextStyle(color: Color(0xFFB9B9C3)),
                    ),
                  )
                // Nếu đã chọn rạp: lắng nghe snacks của rạp đó
                : StreamBuilder<DatabaseEvent>(
                    stream: _database
                        .child('cinemas/$selectedCinemaId/snacks')
                        .onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData ||
                          snapshot.data!.snapshot.value == null) {
                        // Không có danh sách snack cho rạp này
                        return const Center(
                          child: Text(
                            'Không có dữ liệu bắp nước',
                            style: TextStyle(color: Color(0xFFB9B9C3)),
                          ),
                        );
                      }

                      // Chuẩn hoá snapshot (Map hoặc List) về Map<dynamic, dynamic>
                      final data = snapshot.data!.snapshot.value;
                      Map<dynamic, dynamic> snacksMap = {};
                      if (data is Map) {
                        snacksMap = data;
                      } else if (data is List) {
                        for (int i = 0; i < data.length; i++) {
                          if (data[i] != null) snacksMap[i] = data[i];
                        }
                      }

                      // Chuyển map -> List<Snack> domain model
                      final snacks = snacksMap.entries.map((entry) {
                        final s = Map<String, dynamic>.from(entry.value);

                        // ✅ Giá chuẩn hoá về VND (đồng)
                        final priceVND = _toVND(s['price']).toDouble();

                        // ✅ Ảnh lấy an toàn theo nhiều key
                        final image = _getImageUrl(s);

                        return Snack(
                          id: (s['id'] ?? entry.key).toString(),
                          name: (s['name'] ?? '').toString(),
                          price: priceVND, // <-- đã là VND
                          imageUrl: image,
                          description: (s['description'] ?? '').toString(),
                        );
                      }).toList();

                      // Lưới món snack 2 cột
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, // 2 cột
                              childAspectRatio: 0.75, // tỉ lệ thẻ
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: snacks.length,
                        itemBuilder: (context, i) => _buildSnackCard(snacks[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Thẻ hiển thị 1 món snack (ảnh, tên, giá, nút Thêm)
  Widget _buildSnackCard(Snack snack) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh snack (có placeholder/error an toàn)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: snack.imageUrl ?? '',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 600, // giảm RAM khi cache
              filterQuality: FilterQuality.low, // load nhanh hơn
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => Container(
                height: 120,
                color: const Color(0xFF222230),
                child: const Icon(Icons.fastfood, color: Color(0xFFB9B9C3)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: const Color(0xFF222230),
                child: const Icon(Icons.fastfood, color: Color(0xFFB9B9C3)),
              ),
            ),
          ),
          // Nội dung: tên + giá + nút Thêm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên món
                Text(
                  snack.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEDEDED),
                  ),
                ),
                const SizedBox(height: 4),
                // Giá (VND) đã format
                Text(
                  _fmtCurrency(snack.price),
                  style: const TextStyle(color: Color(0xFF8B1E9B)),
                ),
                const SizedBox(height: 6),
                // Nút thêm vào giỏ
                ElevatedButton(
                  onPressed: () => addToCart(snack),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1E9B),
                    minimumSize: const Size(double.infinity, 35),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
