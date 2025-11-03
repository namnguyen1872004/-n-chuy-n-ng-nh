// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

/// ============================
///   MÀN HÌNH TRANG CHỦ (HOME)
/// ============================
/// Nhiệm vụ:
/// - Đọc dữ liệu phim từ Firebase Realtime Database (node /movies) 1 lần khi mở màn
/// - Tách phim thành 2 nhóm: đang chiếu (releaseDate < now) & sắp chiếu (releaseDate > now)
/// - Cho phép lọc thể loại độc lập cho mỗi nhóm (bottom sheet)
/// - Có thanh tìm kiếm mở SearchDelegate, và BottomNavigationBar điều hướng
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Danh sách phim sau khi lấy và parse từ DB
  List<Movie> movies = [];

  // Cờ hiển thị spinner khi đang tải
  bool isLoading = true;

  // Con trỏ gốc tới Firebase Realtime Database
  // .ref() trả về DatabaseReference, dùng .child('movies') để đọc node con
  final _database = FirebaseDatabase.instance.ref();

  // Vị trí tab đang chọn trong BottomNavigationBar
  int _selectedIndex = 0;

  // Thể loại đang lọc cho "Phim đang chiếu" (null = không lọc)
  String? _selectedGenreNow;

  // Thể loại đang lọc cho "Phim sắp chiếu" (null = không lọc)
  String? _selectedGenreComing;

  @override
  void initState() {
    super.initState();
    // Khi màn hình được tạo lần đầu, gọi đọc dữ liệu
    _fetchMovies();
  }

  /// 🔹 Lấy danh sách phim từ Firebase Realtime Database
  /// - Đọc 1 lần (GET) tại node /movies
  /// - parse kết quả có thể là Map (key-value) hoặc List (index-based)
  /// - Sau khi parse thành List<Movie>, setState để cập nhật UI
  Future<void> _fetchMovies() async {
    try {
      // Gọi GET /movies 1 lần
      final snapshot = await _database.child('movies').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final fetched = <Movie>[];
      final data = snapshot.value;

      // Firebase có thể trả Map hoặc List; xử lý cả 2
      if (data is Map) {
        // Map<dynamic, dynamic> -> duyệt từng value (v)
        data.forEach((_, v) {
          if (v is Map) {
            // Ép kiểu an toàn rồi truyền cho Movie.fromMap (do bạn định nghĩa)
            fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
          }
        });
      } else if (data is List) {
        // Nếu là List -> duyệt từng phần tử
        for (final v in data) {
          if (v is Map) {
            fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
          }
        }
      }

      // Cập nhật state sau khi tải xong
      setState(() {
        movies = fetched; // lưu danh sách phim đã parse
        isLoading = false; // tắt spinner
      });
    } catch (e) {
      // Nếu lỗi, tắt spinner và log
      setState(() => isLoading = false);
      debugPrint('Error fetching movies: $e');
    }
  }

  /// 🔹 Xử lý sự kiện khi bấm vào icon trong thanh bottom navigation
  /// - Chỉ số 0 là HOME (đang ở trang này) → không push
  /// - Các chỉ số 1..3 sẽ push tới route định nghĩa sẵn
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/home', '/cinema', '/snack', '/profile'];
    if (index > 0 && index < routes.length) {
      Navigator.pushNamed(context, routes[index]);
    }
  }

  /// 🔹 Mở bottom sheet chọn thể loại
  /// - isNowShowing = true: set lọc cho nhóm "đang chiếu"
  /// - isNowShowing = false: set lọc cho nhóm "sắp chiếu"
  void _showGenreFilter({required bool isNowShowing}) {
    // Gom tất cả thể loại từ toàn bộ danh sách phim -> loại trùng -> sort
    final genres =
        movies
            .expand((m) => m.genre.split(',').map((g) => g.trim()))
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // Mở bottom sheet (nền trong suốt)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GenreFilterSheet(
        genres: genres,
        // Khi chọn 1 thể loại (hoặc "Tất cả" = null), cập nhật biến lọc
        onSelect: (selected) {
          setState(() {
            if (isNowShowing) {
              _selectedGenreNow = selected;
            } else {
              _selectedGenreComing = selected;
            }
          });
        },
      ),
    );
  }

  /// 🔹 Giao diện chính
  @override
  Widget build(BuildContext context) {
    // Nếu đang tải dữ liệu, hiển thị spinner full màn
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
        ),
      );
    }

    // Lấy thời điểm hiện tại để so sánh ngày phát hành
    final now = DateTime.now();

    // Phân loại phim theo ngày phát hành
    final nowShowing = movies
        .where(
          (m) => m.releaseDate.isBefore(now),
        ) // đang chiếu: ngày phát hành < hiện tại
        .toList();

    final comingSoon =
        movies
            .where(
              (m) => m.releaseDate.isAfter(now),
            ) // sắp chiếu: ngày phát hành > hiện tại
            .toList()
          ..sort(
            (a, b) => a.releaseDate.compareTo(b.releaseDate),
          ); // sắp theo ngày phát hành tăng dần

    // Áp dụng bộ lọc thể loại nếu có chọn (null = không lọc)
    final filteredNow = _selectedGenreNow == null
        ? nowShowing
        : nowShowing
              .where((m) => m.genre.contains(_selectedGenreNow!))
              .toList();

    final filteredComing = _selectedGenreComing == null
        ? comingSoon
        : comingSoon
              .where((m) => m.genre.contains(_selectedGenreComing!))
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),

      // AppBar custom: thanh tìm kiếm "giả" -> bấm mở SearchDelegate
      appBar: _buildSearchBar(context),

      // Nội dung chính cuộn dọc
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Slider phim nổi bật: lấy từ nhóm đang chiếu
            MovieCarousel(movies: nowShowing),

            // Header + nút filter cho "Phim đang chiếu"
            SectionHeader(
              title: 'Phim đang chiếu',
              genre: _selectedGenreNow, // hiển thị tag thể loại đang lọc
              onFilterTap: () => _showGenreFilter(isNowShowing: true),
            ),
            // Danh sách ngang phim đang chiếu (đã áp lọc)
            MovieHorizontalList(list: filteredNow),

            // Header + nút filter cho "Phim sắp chiếu"
            SectionHeader(
              title: 'Phim sắp chiếu',
              genre: _selectedGenreComing,
              onFilterTap: () => _showGenreFilter(isNowShowing: false),
            ),
            // Danh sách ngang phim sắp chiếu (đã áp lọc)
            MovieHorizontalList(list: filteredComing),
          ],
        ),
      ),

      // Thanh điều hướng dưới cùng
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 🔍 Thanh tìm kiếm phim — mở SearchDelegate khi bấm vào
  /// - Không nhập trực tiếp ở đây; chỉ là 1 container bắt tap để mở Search UI
  PreferredSizeWidget _buildSearchBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0B0B0F),
      elevation: 0,
      title: GestureDetector(
        onTap: () {
          // Mở SearchDelegate, truyền toàn bộ danh sách movies hiện có
          showSearch(context: context, delegate: MovieSearchDelegate(movies));
        },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF151521),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: const [
              Icon(Icons.search, color: Colors.white), // icon trắng
              SizedBox(width: 8),
              Text(
                'Tìm phim, rạp chiếu...',
                style: TextStyle(
                  color: Colors.white, // placeholder trắng
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Nút thông báo minh hoạ
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          tooltip: 'Thông báo',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa có thông báo mới')),
            );
          },
        ),
      ],
    );
  }

  /// 🔹 Thanh điều hướng dưới cùng
  /// - Giữ theme tối, màu chọn là tím (#8B1E9B)
  /// - Khi tap: gọi _onItemTapped để push route nếu không phải HOME
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF151521),
        selectedItemColor: const Color(0xFF8B1E9B),
        unselectedItemColor: const Color(0xFFB9B9C3),
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'CHỌN RẠP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_drink),
            label: 'BẮP NƯỚC',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
        ],
      ),
    );
  }
}

/// ============================
///     CÁC WIDGET CON PHỤ
/// ============================

/// 🎞️ Slider phim nổi bật
/// - Dùng package carousel_slider
/// - Tự động chạy, phóng to item trung tâm, chỉ lấy tối đa 5 phim (tránh nặng)
class MovieCarousel extends StatelessWidget {
  final List<Movie> movies;
  const MovieCarousel({super.key, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: carousel.CarouselSlider.builder(
        options: carousel.CarouselOptions(
          height: 300,
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 0.8,
        ),
        // Chỉ render tối đa 5 item để mượt hơn
        itemCount: movies.length.clamp(0, 5),
        itemBuilder: (context, index, _) {
          final movie = movies[index];
          return GestureDetector(
            // Bấm vào poster -> mở màn chi tiết (route /details), truyền Movie làm arguments
            onTap: () =>
                Navigator.pushNamed(context, '/details', arguments: movie),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: movie.posterUrl,
                fit: BoxFit.cover,
                // Hiển thị spinner nhỏ khi ảnh chưa tải xong
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                ),
                // Nếu lỗi ảnh -> icon báo lỗi
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 🏷️ Tiêu đề từng phần phim + nút lọc thể loại
class SectionHeader extends StatelessWidget {
  final String title; // tên section: "Phim đang chiếu" / "Phim sắp chiếu"
  final String? genre; // thể loại đang lọc (null = không lọc)
  final VoidCallback onFilterTap; // hàm mở bottom sheet

  const SectionHeader({
    super.key,
    required this.title,
    required this.genre,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tiêu đề section
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // Nút filter: hiện "Bộ lọc" hoặc "Bộ lọc: <genre>"
          TextButton.icon(
            onPressed: onFilterTap,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            label: Text(
              genre == null ? 'Bộ lọc' : 'Bộ lọc: $genre',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎬 Danh sách phim ngang (sử dụng ListView.builder để hiệu năng tốt)
class MovieHorizontalList extends StatelessWidget {
  final List<Movie> list;
  const MovieHorizontalList({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220, // cố định chiều cao item ngang
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        itemBuilder: (context, index) => MovieCard(movie: list[index]),
      ),
    );
  }
}

/// 🎫 Thẻ phim (poster + tên phim)
/// - onTap poster -> mở màn chi tiết /details
class MovieCard extends StatelessWidget {
  final Movie movie;
  const MovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130, // chiều rộng mỗi thẻ
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Poster chiếm phần lớn chiều cao
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/details', arguments: movie),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tên phim, tối đa 2 dòng, căn giữa
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// 📋 Bottom sheet chọn thể loại
/// - Hiển thị danh sách thể loại đã tổng hợp từ toàn bộ phim
/// - Dòng đầu "Tất cả" -> trả null để xóa lọc
class GenreFilterSheet extends StatelessWidget {
  final List<String> genres; // danh sách thể loại duy nhất (đã sort)
  final ValueChanged<String?> onSelect; // callback khi chọn (null = tất cả)

  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, // không chiếm full, cho phép kéo
      initialChildSize: 0.7, // mở lên khoảng 70% chiều cao
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0B0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header của sheet
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn thể loại',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              // Danh sách thể loại có thể cuộn
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: genres.length + 1, // +1 cho mục "Tất cả"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Mục đầu: xóa lọc
                      return ListTile(
                        title: const Text(
                          'Tất cả',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          onSelect(null);
                          Navigator.pop(context);
                        },
                      );
                    }
                    final g = genres[index - 1];
                    return ListTile(
                      title: Text(
                        g,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        onSelect(g); // trả về thể loại được chọn
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ============================
///   SEARCH DELEGATE (TÌM KIẾM)
/// ============================
/// - Cấu trúc chuẩn của Flutter để làm UI tìm kiếm full-screen
/// - Tận dụng danh sách "movies" đã có; không gọi DB lần nữa
class MovieSearchDelegate extends SearchDelegate<String> {
  final List<Movie> movies; // danh sách nguồn để lọc
  final String initialQuery; // nếu muốn mở sẵn với query mặc định

  MovieSearchDelegate(this.movies, {this.initialQuery = ''}) {
    query = initialQuery; // gán query ban đầu
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    // Tùy biến theme cho giao diện search (nền tối, chữ trắng)
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B0B0F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0B0F),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          color: Colors.white70, // placeholder trắng
        ),
        filled: true,
        fillColor: const Color(0xFF151521),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white), // text nhập vào màu trắng
      ),
    );
  }

  // Nút action bên phải (nút xóa query)
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear, color: Colors.white),
      onPressed: () => query = '',
    ),
  ];

  // Nút leading bên trái (quay lại)
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => close(context, ''), // đóng search, trả về chuỗi rỗng
  );

  // Kết quả tìm kiếm khi nhấn submit/search
  @override
  Widget buildResults(BuildContext context) {
    final results = _filterMovies(query);
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy phim nào',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Danh sách kết quả: hiển thị poster + tên + đạo diễn
    return Container(
      color: const Color(0xFF0B0B0F),
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final movie = results[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: movie.posterUrl,
                width: 55,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              movie.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Đạo diễn: ${movie.director}',
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () {
              // Mở màn chi tiết, truyền movie
              Navigator.pushNamed(context, '/details', arguments: movie).then(
                (_) => close(context, movie.title),
              ); // đóng search khi quay lại
            },
          );
        },
      ),
    );
  }

  // Gợi ý realtime khi gõ (không cần submit)
  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterMovies(query);
    return Container(
      color: const Color(0xFF0B0B0F),
      child: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final movie = suggestions[index];
          return ListTile(
            title: Text(
              movie.title,
              style: const TextStyle(color: Colors.white70),
            ),
            // bấm gợi ý -> đổ text vào ô tìm kiếm (chưa điều hướng)
            onTap: () => query = movie.title,
          );
        },
      ),
    );
  }

  /// Lọc danh sách phim theo từ khóa (không phân biệt hoa/thường)
  /// - Nếu query rỗng, trả [] (để suggestions trống, UI gọn gàng)
  /// - So khớp theo title hoặc director
  List<Movie> _filterMovies(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return movies.where((m) {
      return m.title.toLowerCase().contains(lower) ||
          m.director.toLowerCase().contains(lower);
    }).toList();
  }
}
