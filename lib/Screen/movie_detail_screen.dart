import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'booking_screen.dart'; // Đảm bảo import đúng

class MovieDetailScreen extends StatelessWidget {
  final Movie movie;
  final DateTime now = DateTime(
    2025,
    10,
    18,
    2,
    27,
    0,
  ); // 02:27 AM +07, Saturday, October 18, 2025

  // Thêm 2 tham số tùy chọn cho trailer và gallery
  final String? trailerUrl;
  final List<String>? galleryImages;

  MovieDetailScreen({
    super.key,
    required this.movie,
    this.trailerUrl,
    this.galleryImages,
  });

  // Hàm xem ảnh full screen
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

  @override
  Widget build(BuildContext context) {
    // --- YouTube Controller ---
    YoutubePlayerController? youtubeController;
    if (movie.trailerUrl != null && movie.trailerUrl!.contains('youtube.com')) {
      final videoId = YoutubePlayer.convertUrlToId(movie.trailerUrl!);
      if (videoId != null) {
        youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      }
    }

    final isNowShowing = movie.releaseDate.isBefore(now);

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
                // Poster phim chính
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
                          // gradient để chữ/overlay sau này nếu cần
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

                      // Thông tin cơ bản
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

                      // Thể loại
                      const SizedBox(height: 2),
                      Text(
                        'Thể loại: ${movie.genre}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB9B9C3),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // === VIDEO TRAILER ===
                      if (movie.trailerUrl != null &&
                          movie.trailerUrl!.isNotEmpty)
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

                            if (youtubeController != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: YoutubePlayer(
                                  controller: youtubeController!,
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

                      // === GALLERY ẢNH PHIM ===
                      if (movie.galleryImages != null &&
                          movie.galleryImages!.isNotEmpty)
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
                                itemCount: movie.galleryImages!.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => _viewImageFullscreen(
                                      context,
                                      movie.galleryImages![index],
                                    ),
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
                                          imageUrl: movie.galleryImages![index],
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
                                imageBuilder: (context, imageProvider) =>
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: imageProvider,
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
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: const Color(0xFF151521),
                                      child: const Icon(
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFEDEDED),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    CircleAvatar(
                                                      radius: 30,
                                                      backgroundImage:
                                                          imageProvider,
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
                                                ) => CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: const Color(
                                                    0xFF151521,
                                                  ),
                                                  child: const Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Color(0xFFB9B9C3),
                                                  ),
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            movie.actors[index],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFEDEDED),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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

                      // Đánh giá sao
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
                      // Thêm khoảng trống để tránh button che nội dung
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // === NÚT MUA VÉ - STICKY BOTTOM ===
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(movie: movie),
                        ),
                      );
                    },
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
