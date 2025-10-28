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
  String? _selectedGenre; // for "Phim sắp chiếu"
  String? _selectedGenreNow; // for "Phim đang chiếu"

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
              try {
                fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
              } catch (_) {}
            }
          });
        } else if (data is List<dynamic>) {
          for (final v in data) {
            if (v is Map<dynamic, dynamic>) {
              try {
                fetched.add(Movie.fromMap(Map<String, dynamic>.from(v)));
              } catch (_) {}
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
        Navigator.pushNamed(context, '/genres');
        break;
      case 4:
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
      backgroundColor: const Color(0xFF0B0B0F),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chọn thể loại',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFFEDEDED)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Tất cả',
                            style: TextStyle(color: Color(0xFFEDEDED)),
                          ),
                          leading: Radio<String?>(
                            value: null,
                            groupValue: forNowShowing
                                ? _selectedGenreNow
                                : _selectedGenre,
                            onChanged: (v) {
                              setState(() {
                                if (forNowShowing) {
                                  _selectedGenreNow = v;
                                } else {
                                  _selectedGenre = v;
                                }
                              });
                              Navigator.pop(context);
                            },
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
                        ),
                        ...genreList.map(
                          (g) => ListTile(
                            title: Text(
                              g,
                              style: const TextStyle(color: Color(0xFFEDEDED)),
                            ),
                            leading: Radio<String?>(
                              value: g,
                              groupValue: forNowShowing
                                  ? _selectedGenreNow
                                  : _selectedGenre,
                              onChanged: (v) {
                                setState(() {
                                  if (forNowShowing)
                                    _selectedGenreNow = v;
                                  else
                                    _selectedGenre = v;
                                });
                                Navigator.pop(context);
                              },
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        elevation: 0,
        title: const Text(
          'PhimHay.net',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFEDEDED)),
            onPressed: () => showSearch(
              context: context,
              delegate: MovieSearchDelegate(movies),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFFEDEDED)),
                cursorColor: const Color(0xFF8B1E9B),
                decoration: InputDecoration(
                  hintText: 'Tìm phim, rạp chiếu...',
                  hintStyle: const TextStyle(color: Color(0xFFB9B9C3)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFB9B9C3),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF151521),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF8B1E9B),
                      width: 1,
                    ),
                  ),
                ),
                onSubmitted: (v) {
                  if (v.isNotEmpty)
                    showSearch(
                      context: context,
                      delegate: MovieSearchDelegate(movies, initialQuery: v),
                    );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: carousel.CarouselSlider(
                options: carousel.CarouselOptions(
                  height: 300,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.8,
                ),
                items: nowShowing.take(5).map((movie) {
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: movie,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: movie.posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF8B1E9B),
                                ),
                              ),
                              errorWidget: (c, u, e) => Container(
                                color: const Color(0xFF151521),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFFB9B9C3),
                                ),
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xAA000000),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 10,
                              right: 10,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFEDEDED),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFFFC107),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          movie.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Color(0xFFEDEDED),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Now showing header + filter
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Phim đang chiếu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showGenreFilterSheet(forNowShowing: true),
                    icon: const Icon(
                      Icons.filter_list,
                      color: Color(0xFFEDEDED),
                    ),
                    label: Text(
                      _selectedGenreNow == null
                          ? 'Bộ lọc'
                          : 'Bộ lọc: $_selectedGenreNow',
                      style: const TextStyle(color: Color(0xFFEDEDED)),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF151521),
                      side: BorderSide(color: Colors.white12),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredNowShowing.length,
                itemBuilder: (context, index) {
                  final movie = filteredNowShowing[index];
                  return _movieCard(movie);
                },
              ),
            ),

            // Coming soon header + filter
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Phim sắp chiếu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _showGenreFilterSheet(forNowShowing: false),
                    icon: const Icon(
                      Icons.filter_list,
                      color: Color(0xFFEDEDED),
                    ),
                    label: Text(
                      _selectedGenre == null
                          ? 'Bộ lọc'
                          : 'Bộ lọc: $_selectedGenre',
                      style: const TextStyle(color: Color(0xFFEDEDED)),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF151521),
                      side: BorderSide(color: Colors.white12),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredComingSoon.length > 6
                    ? 6
                    : filteredComingSoon.length,
                itemBuilder: (context, index) {
                  final movie = filteredComingSoon[index];
                  return _movieCard(movie);
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 24),
            activeIcon: Icon(Icons.home, size: 28),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on, size: 24),
            activeIcon: Icon(Icons.location_on, size: 28),
            label: 'CHỌN RẠP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_drink, size: 24),
            activeIcon: Icon(Icons.local_drink, size: 28),
            label: 'BẮP NƯỚC',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category, size: 24),
            activeIcon: Icon(Icons.category, size: 28),
            label: 'NHÓM PHIM',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 24),
            activeIcon: Icon(Icons.person, size: 28),
            label: 'PROFILE',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF8B1E9B),
        unselectedItemColor: const Color(0xFFB9B9C3),
        backgroundColor: const Color(0xFF151521),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _movieCard(Movie movie) {
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
              child: Container(
                height: 160,
                width: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    height: 160,
                    width: 130,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B1E9B),
                      ),
                    ),
                    errorWidget: (c, u, e) => Container(
                      color: const Color(0xFF151521),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFFB9B9C3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/details', arguments: movie),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  movie.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEDEDED),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MovieSearchDelegate extends SearchDelegate<String> {
  final List<Movie> movies;
  final String initialQuery;

  MovieSearchDelegate(this.movies, {this.initialQuery = ''}) {
    query = initialQuery.isNotEmpty ? initialQuery : '';
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear, color: Color(0xFFEDEDED)),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDED)),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = _filterMovies(query);
    if (results.isEmpty)
      return const Center(
        child: Text(
          'Không tìm thấy phim nào',
          style: TextStyle(color: Color(0xFFB9B9C3)),
        ),
      );
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final movie = results[index];
        return ListTile(
          tileColor: const Color(0xFF0B0B0F),
          leading: CachedNetworkImage(
            imageUrl: movie.posterUrl,
            width: 50,
            height: 75,
            fit: BoxFit.cover,
            placeholder: (c, u) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            ),
            errorWidget: (c, u, e) => Container(
              color: const Color(0xFF151521),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFB9B9C3),
              ),
            ),
          ),
          title: Text(
            movie.title,
            style: const TextStyle(color: Color(0xFFEDEDED)),
          ),
          subtitle: Text(
            'Đạo diễn: ${movie.director}',
            style: const TextStyle(color: Color(0xFFB9B9C3)),
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
            style: const TextStyle(color: Color(0xFFEDEDED)),
          ),
          onTap: () => query = movie.title,
        );
      },
    );
  }

  List<Movie> _filterMovies(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return movies
        .where(
          (m) =>
              m.title.toLowerCase().contains(lower) ||
              m.director.toLowerCase().contains(lower) ||
              m.actors.join(' ').toLowerCase().contains(lower),
        )
        .toList();
  }
}
