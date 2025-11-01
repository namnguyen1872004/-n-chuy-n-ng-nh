import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/movie.dart';
import 'booking_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.trailerUrl,
    this.galleryImages,
  });

  final Movie movie;

  /// Tuỳ chọn: nếu muốn override trailer trong movie
  final String? trailerUrl;

  /// Tuỳ chọn: nếu muốn override gallery trong movie
  final List<String>? galleryImages;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // Ví dụ “thời điểm hiện tại” cố định để demo
  final DateTime _now = DateTime(2025, 10, 18, 2, 27, 0);

  YoutubePlayerController? _ytController;

  // ---------- Lifecycle ----------
  @override
  void initState() {
    super.initState();

    // Lấy URL trailer: ưu tiên tham số truyền vào, fallback về movie.trailerUrl
    final url = widget.trailerUrl ?? widget.movie.trailerUrl;
    if (url != null && url.contains('youtube.com')) {
      final id = YoutubePlayer.convertUrlToId(url);
      if (id != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      _ytController?.pause();
      _ytController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ---------- Helpers ----------
  void _viewImageFullscreen(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToBooking() {
    // RẤT QUAN TRỌNG: tạm dừng trailer trước khi rời màn
    try {
      _ytController?.pause();
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(movie: widget.movie),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final isNowShowing = movie.releaseDate.isBefore(_now);

    // Nếu muốn dùng gallery override, lấy từ widget.galleryImages, không thì movie.galleryImages
    final gallery = widget.galleryImages ?? movie.galleryImages;

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
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDED)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster chính
                GestureDetector(
                  onTap: () => _viewImageFullscreen(context, movie.posterUrl),
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
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
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF8B1E9B),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF151521),
                              height: 300,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFB9B9C3),
                              ),
                            ),
                          ),
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEDEDED),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Info cơ bản
                      Row(
                        children: [
                          Text(
                            'Thời lượng: ${movie.duration} phút',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB9B9C3),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Khởi chiếu: ${movie.releaseDate.day}/${movie.releaseDate.month}/${movie.releaseDate.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB9B9C3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Thể loại: ${movie.genre}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB9B9C3),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Trailer
                      if ((widget.trailerUrl ?? movie.trailerUrl)?.isNotEmpty ??
                          false)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trailer:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEDEDED),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_ytController != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: YoutubePlayer(
                                  controller: _ytController!,
                                  showVideoProgressIndicator: true,
                                  progressIndicatorColor: Colors.redAccent,
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Không thể phát trailer'),
                                      ),
                                    ),
                                child: Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151521),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF222230),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Color(0xFFEDEDED),
                                      size: 60,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),

                      // Gallery ảnh
                      if (gallery != null && gallery.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hình ảnh:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEDEDED),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: gallery.length,
                                itemBuilder: (context, index) {
                                  final img = gallery[index];
                                  return GestureDetector(
                                    onTap: () =>
                                        _viewImageFullscreen(context, img),
                                    child: Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.35,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: img,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFF8B1E9B),
                                                    ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
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
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                      // Đạo diễn
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đạo diễn:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEDEDED),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              CachedNetworkImage(
                                imageUrl: movie.directorImageUrl.isNotEmpty
                                    ? movie.directorImageUrl
                                    : 'https://via.placeholder.com/60?text=Director',
                                imageBuilder: (context, provider) =>
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: provider,
                                    ),
                                placeholder: (context, url) =>
                                    const CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Color(0xFF222230),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF8B1E9B),
                                        ),
                                      ),
                                    ),
                                errorWidget: (context, url, error) =>
                                    const CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Color(0xFF151521),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Color(0xFFB9B9C3),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  movie.director,
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Diễn viên
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diễn viên:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEDEDED),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (movie.actors.isNotEmpty)
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: movie.actors.length,
                                itemBuilder: (context, index) {
                                  final imageUrl =
                                      index < movie.actorsImageUrls.length &&
                                          movie
                                              .actorsImageUrls[index]
                                              .isNotEmpty
                                      ? movie.actorsImageUrls[index]
                                      : 'https://via.placeholder.com/60?text=Actor';
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: SizedBox(
                                      width: 70,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            imageBuilder: (context, provider) =>
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundImage: provider,
                                                ),
                                            placeholder: (context, url) =>
                                                const CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: Color(
                                                    0xFF222230,
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Color(
                                                            0xFF8B1E9B,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => const CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: Color(
                                                    0xFF151521,
                                                  ),
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Color(0xFFB9B9C3),
                                                  ),
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            movie.actors[index],
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFEDEDED),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Mô tả
                      Text(
                        movie.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFEDEDED),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Đánh giá
                      if (isNowShowing)
                        Row(
                          children: [
                            for (int i = 1; i <= 5; i++)
                              Icon(
                                i <= (movie.rating / 1).floor()
                                    ? Icons.star
                                    : i - 1 < movie.rating
                                    ? Icons.star_half
                                    : Icons.star_border,
                                color: const Color(0xFFFFC107),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              '${movie.rating.toStringAsFixed(1)}/5 (${(1000 * movie.rating).toInt()} đánh giá)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFB9B9C3),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 120), // chừa chỗ cho nút dưới
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nút mua vé
          if (isNowShowing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151521),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 16,
                      offset: const Offset(0, -8),
                    ),
                  ],
                  border: const Border(
                    top: BorderSide(color: Color(0xFF222230)),
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: SafeArea(
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
                        Icon(Icons.confirmation_number_outlined, size: 24),
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
}
