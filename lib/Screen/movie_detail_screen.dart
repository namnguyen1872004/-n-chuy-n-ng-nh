import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/movie.dart';
import 'booking_screen.dart';

/// ------------------------------------------------------------
/// Màn chi tiết phim + trailer + gallery + nút “Mua vé”
/// - Nhận Movie; có thể override trailerUrl / galleryImages qua props
/// - Tự nhận nhiều dạng link YouTube (youtube.com / youtu.be)
/// - Tạm dừng trailer khi chuyển trang
/// - UI dark, gọn, có placeholder/error an toàn
/// ------------------------------------------------------------
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.trailerUrl,
    this.galleryImages,
  });

  final Movie movie;
  final String? trailerUrl; // override trailer nếu muốn
  final List<String>? galleryImages; // override gallery nếu muốn

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  YoutubePlayerController? _yt;

  // ---------------- Helpers: YouTube & format ----------------

  /// Lấy ID video từ nhiều dạng link YouTube
  String? _extractYoutubeId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    // youtube_player_flutter đã có helper — tận dụng:
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Dừng video an toàn
  void _pauseTrailer() {
    try {
      _yt?.pause();
    } catch (_) {}
  }

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    final url = widget.trailerUrl?.trim().isNotEmpty == true
        ? widget.trailerUrl!.trim()
        : (widget.movie.trailerUrl ?? '').trim();

    final id = _extractYoutubeId(url);
    if (id != null) {
      _yt = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: false,
          // nếu muốn video không phát nền khi thu nhỏ:
          disableDragSeek: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pauseTrailer();
    _yt?.dispose();
    super.dispose();
  }

  // ---------------- Navigation ----------------
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
    final movie = widget.movie;

    // Đang chiếu? (so với thời điểm thật)
    final bool isNowShowing = movie.releaseDate.isBefore(DateTime.now());

    // Gallery: ưu tiên override, fallback movie.galleryImages
    final List<String> gallery =
        (widget.galleryImages != null && widget.galleryImages!.isNotEmpty)
        ? widget.galleryImages!
        : movie.galleryImages;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
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
            _pauseTrailer();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------- Poster lớn --------
                GestureDetector(
                  onTap: () => _viewImageFullscreen(movie.posterUrl),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
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
                          // viền gradient tối phần dưới cho chữ dễ đọc
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

                // -------- Thông tin cơ bản --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      const SizedBox(height: 8),
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

                      // -------- Trailer --------
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
                            aspectRatio: 16 / 9,
                            child: YoutubePlayer(
                              controller: _yt!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // -------- Gallery ảnh --------
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
                        placeholderText: 'Director',
                      ),
                      const SizedBox(height: 16),

                      // -------- Diễn viên --------
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
                              imageUrl: (i < movie.actorsImageUrls.length)
                                  ? movie.actorsImageUrls[i]
                                  : '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // -------- Mô tả --------
                      Text(
                        movie.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFEDEDED),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -------- Đánh giá sao (nếu đã chiếu) --------
                      if (isNowShowing) _ratingRow(movie.rating),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -------- Nút Mua vé (chỉ khi đã khởi chiếu) --------
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
                  top: false,
                  child: ElevatedButton(
                    onPressed: _goToBooking,
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

  // ---------------- Widgets con nhỏ gọn ----------------

  Widget _infoChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF151521),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF222230)),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFFB9B9C3))),
  );

  Widget _galleryThumb(String url) => GestureDetector(
    onTap: () => _viewImageFullscreen(url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 3,
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

  Widget _personAvatar({
    required String name,
    required String imageUrl,
    required String placeholderText,
  }) {
    final url = imageUrl.isNotEmpty
        ? imageUrl
        : 'https://via.placeholder.com/60?text=$placeholderText';
    return Column(
      children: [
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

  Widget _actorItem({required String name, required String imageUrl}) =>
      _personAvatar(
        name: name,
        imageUrl: imageUrl.isNotEmpty
            ? imageUrl
            : 'https://via.placeholder.com/60?text=Actor',
        placeholderText: 'Actor',
      );

  Widget _ratingRow(double rating) {
    // rating 0..5 (double). Vẽ sao đầy/ nửa/ rỗng.
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
          '${rating.toStringAsFixed(1)}/5',
          style: const TextStyle(color: Color(0xFFB9B9C3)),
        ),
      ],
    );
  }

  void _viewImageFullscreen(String imageUrl) {
    _pauseTrailer(); // tránh phát nền khi xem ảnh
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
