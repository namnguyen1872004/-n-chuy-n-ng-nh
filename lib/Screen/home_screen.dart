// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

/// ============================
///   MÀN HÌNH TRANG CHỦ (HOME)
/// ============================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Danh sách phim và trạng thái tải
  List<Movie> movies = [];
  bool isLoading = true;

  // Kết nối Firebase Database
  final _database = FirebaseDatabase.instance.ref();

  // Chỉ số thanh điều hướng dưới
  int _selectedIndex = 0;

  // Biến lọc thể loại
  String? _selectedGenreNow;
  String? _selectedGenreComing;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
  }

  /// 🔹 Lấy danh sách phim từ Firebase Realtime Database
  Future<void> _fetchMovies() async {
    try {
      final snapshot = await _database.child('movies').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final fetched = <Movie>[];
      final data = snapshot.value;

      // Parse dữ liệu trả về (có thể là Map hoặc List)
      if (data is Map) {
        data.forEach((_, v) {
          if (v is Map)
            fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
        });
      } else if (data is List) {
        for (final v in data) {
          if (v is Map)
            fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
        }
      }

      setState(() {
        movies = fetched;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching movies: $e');
    }
  }

  /// 🔹 Xử lý sự kiện khi bấm vào icon trong thanh bottom navigation
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/home', '/cinema', '/snack', '/profile'];
    if (index > 0 && index < routes.length) {
      Navigator.pushNamed(context, routes[index]);
    }
  }

  /// 🔹 Hiển thị hộp chọn thể loại phim (Bottom Sheet)
  void _showGenreFilter({required bool isNowShowing}) {
    final genres =
        movies
            .expand((m) => m.genre.split(',').map((g) => g.trim()))
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GenreFilterSheet(
        genres: genres,
        onSelect: (selected) {
          setState(() {
            if (isNowShowing)
              _selectedGenreNow = selected;
            else
              _selectedGenreComing = selected;
          });
        },
      ),
    );
  }

  /// 🔹 Giao diện chính
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
        ),
      );
    }

    final now = DateTime.now();

    // Phân loại phim
    final nowShowing = movies
        .where((m) => m.releaseDate.isBefore(now))
        .toList();
    final comingSoon = movies.where((m) => m.releaseDate.isAfter(now)).toList()
      ..sort((a, b) => a.releaseDate.compareTo(b.releaseDate));

    // Áp dụng bộ lọc thể loại
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
      appBar: _buildSearchBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            MovieCarousel(movies: nowShowing),
            SectionHeader(
              title: 'Phim đang chiếu',
              genre: _selectedGenreNow,
              onFilterTap: () => _showGenreFilter(isNowShowing: true),
            ),
            MovieHorizontalList(list: filteredNow),
            SectionHeader(
              title: 'Phim sắp chiếu',
              genre: _selectedGenreComing,
              onFilterTap: () => _showGenreFilter(isNowShowing: false),
            ),
            MovieHorizontalList(list: filteredComing),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 🔍 Thanh tìm kiếm phim — mở SearchDelegate khi bấm vào
  PreferredSizeWidget _buildSearchBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0B0B0F),
      elevation: 0,
      title: GestureDetector(
        onTap: () {
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
              Icon(Icons.search, color: Colors.white), // 🔹 icon trắng
              SizedBox(width: 8),
              Text(
                'Tìm phim, rạp chiếu...',
                style: TextStyle(
                  color: Colors.white, // 🔹 đổi màu chữ sang trắng
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
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
        itemCount: movies.length.clamp(0, 5),
        itemBuilder: (context, index, _) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/details', arguments: movie),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
          );
        },
      ),
    );
  }
}

/// 🏷️ Tiêu đề từng phần phim
class SectionHeader extends StatelessWidget {
  final String title;
  final String? genre;
  final VoidCallback onFilterTap;

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
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

/// 🎬 Danh sách phim ngang
class MovieHorizontalList extends StatelessWidget {
  final List<Movie> list;
  const MovieHorizontalList({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        itemBuilder: (context, index) => MovieCard(movie: list[index]),
      ),
    );
  }
}

/// 🎫 Thẻ phim
class MovieCard extends StatelessWidget {
  final Movie movie;
  const MovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
class GenreFilterSheet extends StatelessWidget {
  final List<String> genres;
  final ValueChanged<String?> onSelect;

  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0B0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
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
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: genres.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
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
                        onSelect(g);
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
class MovieSearchDelegate extends SearchDelegate<String> {
  final List<Movie> movies;
  final String initialQuery;

  MovieSearchDelegate(this.movies, {this.initialQuery = ''}) {
    query = initialQuery;
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
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
          color: Colors.white70,
        ), // 🔹 placeholder trắng
        filled: true,
        fillColor: const Color(0xFF151521),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white), // 🔹 chữ nhập vào màu trắng
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear, color: Colors.white),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => close(context, ''),
  );

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
              Navigator.pushNamed(
                context,
                '/details',
                arguments: movie,
              ).then((_) => close(context, movie.title));
            },
          );
        },
      ),
    );
  }

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
            onTap: () => query = movie.title,
          );
        },
      ),
    );
  }

  /// Lọc danh sách phim theo từ khóa
  List<Movie> _filterMovies(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return movies.where((m) {
      return m.title.toLowerCase().contains(lower) ||
          m.director.toLowerCase().contains(lower);
    }).toList();
  }
}
