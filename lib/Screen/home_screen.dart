import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> movies = [];
  bool isLoading = true;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGenre;
  String? _selectedGenreNow;

  @override
  void initState() {
    super.initState();
    _fetchMoviesFromFirebase();
  }

  Future<void> _fetchMoviesFromFirebase() async {
    try {
      final snapshot = await _database.child('movies').get();
      final List<Movie> fetched = [];
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          data.forEach((_, v) {
            if (v is Map<dynamic, dynamic>) {
              fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
            }
          });
        } else if (data is List<dynamic>) {
          for (final v in data) {
            if (v is Map<dynamic, dynamic>) {
              fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
            }
          }
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

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/cinema');
        break;
      case 2:
        Navigator.pushNamed(context, '/snack');
        break;
      case 3:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  void _showGenreFilterSheet({bool forNowShowing = false}) {
    final genreSet = <String>{};
    for (final m in movies) {
      final parts = m.genre.split(',');
      for (final p in parts) {
        final g = p.trim();
        if (g.isNotEmpty) genreSet.add(g);
      }
    }
    final genreList = genreSet.toList()..sort();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          initialChildSize: 0.7,
          builder: (context, scrollController) {
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
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFEDEDED),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: genreList.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            title: const Text(
                              'Tất cả',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              setState(() {
                                if (forNowShowing)
                                  _selectedGenreNow = null;
                                else
                                  _selectedGenre = null;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }
                        final g = genreList[index - 1];
                        return ListTile(
                          title: Text(
                            g,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            setState(() {
                              if (forNowShowing)
                                _selectedGenreNow = g;
                              else
                                _selectedGenre = g;
                            });
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
      },
    );
  }

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
    final nowShowing = movies
        .where((m) => m.releaseDate.isBefore(now))
        .toList();
    final comingSoon = movies.where((m) => m.releaseDate.isAfter(now)).toList()
      ..sort((a, b) => a.releaseDate.compareTo(b.releaseDate));

    final filteredNowShowing = _selectedGenreNow == null
        ? nowShowing
        : nowShowing
              .where(
                (m) => m.genre
                    .split(',')
                    .map((s) => s.trim())
                    .contains(_selectedGenreNow),
              )
              .toList();

    final filteredComingSoon = _selectedGenre == null
        ? comingSoon
        : comingSoon
              .where(
                (m) => m.genre
                    .split(',')
                    .map((s) => s.trim())
                    .contains(_selectedGenre),
              )
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text(
          'PhimHay.net',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => showSearch(
              context: context,
              delegate: MovieSearchDelegate(movies),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCarousel(nowShowing),
            _buildSectionHeader(
              'Phim đang chiếu',
              _selectedGenreNow,
              () => _showGenreFilterSheet(forNowShowing: true),
            ),
            _buildMovieList(filteredNowShowing),
            _buildSectionHeader(
              'Phim sắp chiếu',
              _selectedGenre,
              () => _showGenreFilterSheet(forNowShowing: false),
            ),
            _buildMovieList(filteredComingSoon),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF8B1E9B),
      decoration: InputDecoration(
        hintText: 'Tìm phim, rạp chiếu...',
        hintStyle: const TextStyle(color: Color(0xFFB9B9C3)),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFB9B9C3)),
        filled: true,
        fillColor: const Color(0xFF151521),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (v) {
        if (v.isNotEmpty) {
          showSearch(
            context: context,
            delegate: MovieSearchDelegate(movies, initialQuery: v),
          );
        }
      },
    ),
  );

  Widget _buildCarousel(List<Movie> movies) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0),
    child: carousel.CarouselSlider(
      options: carousel.CarouselOptions(
        height: 300,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.8,
      ),
      items: movies.take(5).map((movie) {
        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/details', arguments: movie),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: movie.posterUrl,
              fit: BoxFit.cover,
              placeholder: (c, u) => const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
              ),
              errorWidget: (c, u, e) => Container(
                color: const Color(0xFF151521),
                child: const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildSectionHeader(String title, String? genre, VoidCallback onTap) =>
      Padding(
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
              onPressed: onTap,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              label: Text(
                genre == null ? 'Bộ lọc' : 'Bộ lọc: $genre',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

  Widget _buildMovieList(List<Movie> list) => SizedBox(
    height: 220,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) => _movieCard(list[index]),
    ),
  );

  Widget _movieCard(Movie movie) => Container(
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
                placeholder: (c, u) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                ),
                errorWidget: (c, u, e) => Container(
                  color: const Color(0xFF151521),
                  child: const Icon(Icons.broken_image, color: Colors.white38),
                ),
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

// ========== MOVIE SEARCH DELEGATE ==========
class MovieSearchDelegate extends SearchDelegate<String> {
  final List<Movie> movies;
  final String initialQuery;

  MovieSearchDelegate(this.movies, {this.initialQuery = ''}) {
    query = initialQuery;
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
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final movie = results[index];
        return ListTile(
          leading: CachedNetworkImage(
            imageUrl: movie.posterUrl,
            width: 50,
            height: 75,
            fit: BoxFit.cover,
          ),
          title: Text(movie.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            'Đạo diễn: ${movie.director}',
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () => Navigator.pushNamed(
            context,
            '/details',
            arguments: movie,
          ).then((_) => close(context, movie.title)),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterMovies(query);
    return ListView.builder(
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
    );
  }

  List<Movie> _filterMovies(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return movies.where((m) {
      return m.title.toLowerCase().contains(lower) ||
          m.director.toLowerCase().contains(lower) ||
          m.actors.join(' ').toLowerCase().contains(lower);
    }).toList();
  }
}
