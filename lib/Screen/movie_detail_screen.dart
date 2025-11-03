import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/movie.dart';
import 'booking_screen.dart';

/// ------------------------------------------------------------
/// Màn chi tiết phim + trailer + gallery + nút “Mua vé”
/// - Nhận Movie; có thể override trailerUrl / galleryImages qua props
/// - Tự nhận nhiều dạng link YouTube (youtube.com / youtu.be)
/// - Tạm dừng trailer khi chuyển trang (pop/push)
/// - UI dark, có placeholder/error an toàn cho ảnh
/// ------------------------------------------------------------
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.trailerUrl,
    this.galleryImages,
  });

  // Dữ liệu phim chính, bắt buộc phải có
  final Movie movie;

  // Cho phép truyền link trailer khác với trong movie (tuỳ biến từ nơi gọi)
  final String? trailerUrl;

  // Cho phép truyền danh sách ảnh khác (tuỳ biến từ nơi gọi)
  final List<String>? galleryImages;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // Controller cho YouTube player; để null khi không có trailer hợp lệ
  YoutubePlayerController? _yt;

  // ---------------- Helpers: YouTube & định dạng ----------------

  /// Trích ID video YouTube từ nhiều dạng URL (youtu.be / youtube.com)
  /// Thư viện youtube_player_flutter đã có helper: convertUrlToId
  String? _extractYoutubeId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Dừng video an toàn (bọc try/catch để tránh lỗi state không hợp lệ)
  void _pauseTrailer() {
    try {
      _yt?.pause();
    } catch (_) {}
  }

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();

    // 1) Chọn nguồn trailer: ưu tiên trailerUrl truyền vào; fallback movie.trailerUrl
    final url = widget.trailerUrl?.trim().isNotEmpty == true
        ? widget.trailerUrl!.trim()
        : (widget.movie.trailerUrl ?? '').trim();

    // 2) Trích ra YouTube video ID
    final id = _extractYoutubeId(url);

    // 3) Nếu có ID hợp lệ thì khởi tạo controller để nhúng player
    if (id != null) {
      _yt = YoutubePlayerController(
        initialVideoId: id, // ID YouTube
        flags: const YoutubePlayerFlags(
          autoPlay: false, // Không tự phát khi vào màn
          mute: false, // Có tiếng
          forceHD: false, // Không ép HD (để phù hợp mạng yếu)
          // disableDragSeek: false (mặc định: cho phép kéo seek)
        ),
      );
    }
  }

  @override
  void dispose() {
    // Dừng video trước khi huỷ để tránh phát nền (tiếng chạy khi đã rời trang)
    _pauseTrailer();
    // Giải phóng controller để tránh rò rỉ tài nguyên
    _yt?.dispose();
    super.dispose();
  }

  // ---------------- Điều hướng ----------------

  /// Chuyển sang màn đặt vé (BookingScreen)
  /// Trước khi đi, dừng trailer để không phát nền
  void _goToBooking() {
    _pauseTrailer();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingScreen(movie: widget.movie)),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu phim ra cho ngắn
    final movie = widget.movie;

    // Xác định phim đã khởi chiếu hay chưa
    // -> Nếu đã khởi chiếu (releaseDate < thời điểm hiện tại) thì hiển thị nút "Mua vé"
    final bool isNowShowing = movie.releaseDate.isBefore(DateTime.now());

    // Gallery: ưu tiên danh sách truyền vào; nếu không có thì dùng của movie
    final List<String> gallery =
        (widget.galleryImages != null && widget.galleryImages!.isNotEmpty)
        ? widget.galleryImages!
        : movie.galleryImages;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F), // Nền tối đồng bộ
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Thông tin phim',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDED)),
          onPressed: () {
            _pauseTrailer(); // Dừng trailer trước khi back
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // Nội dung chính scroll được
          SingleChildScrollView(
            // Chừa khoảng đáy đủ cao để không bị nút CTA che nội dung
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------- Poster lớn (bấm để xem full-screen) --------
                GestureDetector(
                  onTap: () => _viewImageFullscreen(movie.posterUrl),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        // Đổ bóng dưới poster cho nổi khối
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Ảnh poster: có placeholder và error an toàn
                          CachedNetworkImage(
                            imageUrl: movie.posterUrl,
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF8B1E9B),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 300,
                              color: const Color(0xFF151521),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFB9B9C3),
                              ),
                            ),
                          ),
                          // Lớp gradient tối dưới chân poster để text phía dưới dễ đọc
                          Container(
                            height: 300,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xAA000000)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // -------- Khối thông tin cơ bản của phim --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên phim
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Dòng chip thông tin: thời lượng / ngày khởi chiếu / thể loại
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _infoChip('Thời lượng: ${movie.duration} phút'),
                          _infoChip(
                            'Khởi chiếu: '
                            '${movie.releaseDate.day}/${movie.releaseDate.month}/${movie.releaseDate.year}',
                          ),
                          _infoChip('Thể loại: ${movie.genre}'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // -------- Trailer YouTube (chỉ hiện nếu có controller) --------
                      if (_yt != null) ...[
                        const Text(
                          'Trailer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9, // tỉ lệ video tiêu chuẩn
                            child: YoutubePlayer(
                              controller: _yt!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // -------- Bộ sưu tập ảnh (nếu có) --------
                      if (gallery.isNotEmpty) ...[
                        const Text(
                          'Hình ảnh',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: gallery.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) => _galleryThumb(gallery[i]),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // -------- Đạo diễn --------
                      const Text(
                        'Đạo diễn',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _personAvatar(
                        name: movie.director,
                        imageUrl: movie.directorImageUrl,
                        placeholderText: 'Director', // chữ placeholder trên ảnh
                      ),
                      const SizedBox(height: 16),

                      // -------- Danh sách diễn viên --------
                      if (movie.actors.isNotEmpty) ...[
                        const Text(
                          'Diễn viên',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: movie.actors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) => _actorItem(
                              name: movie.actors[i],
                              // Nếu danh sách ảnh diễn viên thiếu phần tử, fallback rỗng -> _actorItem tự xử lý
                              imageUrl: (i < movie.actorsImageUrls.length)
                                  ? movie.actorsImageUrls[i]
                                  : '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // -------- Mô tả nội dung --------
                      Text(
                        movie.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFEDEDED),
                          height: 1.5, // giãn dòng dễ đọc
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -------- Đánh giá sao (chỉ hiện khi đã khởi chiếu) --------
                      if (isNowShowing) _ratingRow(movie.rating),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -------- Nút “Mua vé” cố định ở đáy (chỉ khi đã khởi chiếu) --------
          if (isNowShowing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF151521),
                  border: Border(top: BorderSide(color: Color(0xFF222230))),
                ),
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false, // không đè lên tai thỏ phía trên
                  child: ElevatedButton(
                    onPressed: _goToBooking, // chuyển sang đặt vé
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E9B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Mua vé',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- Widgets con tái sử dụng ----------------

  /// Ô “chip” hiển thị thông tin ngắn (thời lượng, ngày chiếu, thể loại)
  Widget _infoChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF222230)),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFFB9B9C3))),
  );

  /// Ảnh nhỏ trong gallery (ấn để phóng to)
  Widget _galleryThumb(String url) => GestureDetector(
    onTap: () => _viewImageFullscreen(url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 3, // crop ảnh theo tỉ lệ 4:3
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
          ),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF151521),
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFFB9B9C3),
            ),
          ),
        ),
      ),
    ),
  );

  /// Avatar người (đạo diễn/diễn viên) với fallback nếu thiếu ảnh
  Widget _personAvatar({
    required String name,
    required String imageUrl,
    required String placeholderText,
  }) {
    // Nếu thiếu URL -> dùng ảnh placeholder từ dịch vụ placeholder
    final url = imageUrl.isNotEmpty
        ? imageUrl
        : 'https://via.placeholder.com/60?text=$placeholderText';

    return Column(
      children: [
        // CachedNetworkImage + imageBuilder để nhét vào CircleAvatar
        CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (_, provider) =>
              CircleAvatar(radius: 30, backgroundImage: provider),
          placeholder: (_, __) => const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF222230),
            child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
          ),
          errorWidget: (_, __, ___) => const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF151521),
            child: Icon(Icons.broken_image_outlined, color: Color(0xFFB9B9C3)),
          ),
        ),
        const SizedBox(height: 8),
        // Giới hạn chiều rộng để chữ xuống dòng gọn gàng
        SizedBox(
          width: 100,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFEDEDED),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Item diễn viên: bọc _personAvatar với placeholderText "Actor"
  Widget _actorItem({required String name, required String imageUrl}) =>
      _personAvatar(
        name: name,
        imageUrl: imageUrl.isNotEmpty
            ? imageUrl
            : 'https://via.placeholder.com/60?text=Actor',
        placeholderText: 'Actor',
      );

  /// Hàng hiển thị rating sao: 0..5 (có nửa sao nếu cần)
  Widget _ratingRow(double rating) {
    // Tính số sao đầy / nửa / rỗng
    int full = rating.floor();
    bool hasHalf = (rating - full) >= 0.25 && (rating - full) < 0.75;
    int empty = 5 - full - (hasHalf ? 1 : 0);

    return Row(
      children: [
        for (int i = 0; i < full; i++)
          const Icon(Icons.star, color: Color(0xFFFFC107), size: 20),
        if (hasHalf)
          const Icon(Icons.star_half, color: Color(0xFFFFC107), size: 20),
        for (int i = 0; i < empty; i++)
          const Icon(Icons.star_border, color: Color(0xFFFFC107), size: 20),
        const SizedBox(width: 8),
        Text(
          '${rating.toStringAsFixed(1)}/5', // hiển thị số điểm bên cạnh sao
          style: const TextStyle(color: Color(0xFFB9B9C3)),
        ),
      ],
    );
  }

  /// Màn xem ảnh full-screen: dùng InteractiveViewer để zoom/pan
  void _viewImageFullscreen(String imageUrl) {
    _pauseTrailer(); // dừng trailer để tránh phát nền khi xem ảnh
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
