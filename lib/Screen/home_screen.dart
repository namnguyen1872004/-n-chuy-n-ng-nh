import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/movie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> movies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMoviesFromFirebase();
    // Uncomment để upload dữ liệu nếu cần (hiện tại trống)
    // uploadMoviesToFirebase();
  }

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  // Hàm upload dữ liệu lên Firebase (trống, dùng khi cần thêm dữ liệu mới)
  Future<void> uploadMoviesToFirebase() async {
    // Hàm này trống vì dữ liệu đã có trong Firebase, thêm dữ liệu mới khi cần
    print('Upload dữ liệu lên Firebase (hiện tại không có dữ liệu mẫu)');
  }

  // Hàm tải dữ liệu từ Firebase
  Future<void> _fetchMoviesFromFirebase() async {
    try {
      final snapshot = await _database.child('movies').get();
      print("Raw snapshot value: ${snapshot.value}"); // Debug raw data
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data == null) {
          setState(() {
            isLoading = false;
          });
          print("❌ Dữ liệu từ Firebase là null");
          return;
        }

        List<Movie> fetchedMovies = [];
        if (data is Map<dynamic, dynamic>) {
          print("Data is Map with keys: ${data.keys}"); // Debug Map structure
          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              try {
                print(
                  "Parsing movie with key $key: $value",
                ); // Debug each movie
                fetchedMovies.add(
                  Movie(
                    id: value['id'] as String? ?? '',
                    title: value['title'] as String? ?? 'No Title',
                    description: value['description'] as String? ?? '',
                    duration: (value['duration'] as int?) ?? 0,
                    genre: value['genre'] as String? ?? '',
                    posterUrl: value['posterUrl'] as String? ?? '',
                    releaseDate: value['releaseDate'] != null
                        ? DateTime.parse(value['releaseDate'] as String)
                        : DateTime.now(),
                    director: value['director'] as String? ?? '',
                    actors:
                        (value['actors'] as List<dynamic>?)?.cast<String>() ??
                        [],
                    rating: (value['rating'] as num?)?.toDouble() ?? 0.0,
                    directorImageUrl:
                        value['directorImageUrl'] as String? ?? '',
                    actorsImageUrls:
                        (value['actorsImageUrls'] as List<dynamic>?)
                            ?.cast<String>() ??
                        [],
                    trailerUrl: value['trailerUrl'] as String? ?? '',
                    galleryImages:
                        (value['galleryImages'] as List<dynamic>?)
                            ?.cast<String>() ??
                        [],
                  ),
                );
                print(
                  "Successfully parsed movie: ${value['title']} with posterUrl: ${value['posterUrl']}",
                );
              } catch (e) {
                print("❌ Lỗi parse movie với key $key: $e");
              }
            }
          });
        } else if (data is List<dynamic>) {
          print(
            "Data is List with length: ${data.length}",
          ); // Debug List structure
          for (var value in data) {
            if (value is Map<dynamic, dynamic>) {
              try {
                fetchedMovies.add(
                  Movie(
                    id: value['id'] as String? ?? '',
                    title: value['title'] as String? ?? 'No Title',
                    description: value['description'] as String? ?? '',
                    duration: (value['duration'] as int?) ?? 0,
                    genre: value['genre'] as String? ?? '',
                    posterUrl: value['posterUrl'] as String? ?? '',
                    releaseDate: value['releaseDate'] != null
                        ? DateTime.parse(value['releaseDate'] as String)
                        : DateTime.now(),
                    director: value['director'] as String? ?? '',
                    actors:
                        (value['actors'] as List<dynamic>?)?.cast<String>() ??
                        [],
                    rating: (value['rating'] as num?)?.toDouble() ?? 0.0,
                    directorImageUrl:
                        value['directorImageUrl'] as String? ?? '',
                    actorsImageUrls:
                        (value['actorsImageUrls'] as List<dynamic>?)
                            ?.cast<String>() ??
                        [],
                    trailerUrl: value['trailerUrl'] as String? ?? '',
                    galleryImages:
                        (value['galleryImages'] as List<dynamic>?)
                            ?.cast<String>() ??
                        [],
                  ),
                );
              } catch (e) {
                print("❌ Lỗi parse movie trong list: $e");
              }
            }
          }
        } else {
          print("❌ Dữ liệu không phải Map hoặc List: $data");
        }

        if (fetchedMovies.isEmpty) {
          print("❌ Không có movie nào được parse thành công");
        }

        setState(() {
          movies = fetchedMovies;
          isLoading = false;
        });
        print("✅ Đã tải ${movies.length} phim từ Firebase!");
      } else {
        setState(() {
          isLoading = false;
        });
        print("❌ Không có dữ liệu trong Firebase");
      }
    } catch (e) {
      print("❌ Lỗi khi tải phim: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
        ),
      );
    }

    final now = DateTime.now(); // 12:15 AM +07, Thursday, October 16, 2025
    final nowShowing = movies
        .where((movie) => movie.releaseDate.isBefore(now))
        .toList();
    final comingSoon =
        movies.where((movie) => movie.releaseDate.isAfter(now)).toList()
          ..sort((a, b) => a.releaseDate.compareTo(b.releaseDate));

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
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFEDEDED)),
            onPressed: () {
              print('Mở tìm kiếm từ icon');
              showSearch(
                context: context,
                delegate: MovieSearchDelegate(movies),
              );
            },
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
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFFB9B9C3),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: (value) {
                  print('Tìm kiếm từ TextField với query: "$value"');
                  if (value.isNotEmpty) {
                    showSearch(
                      context: context,
                      delegate: MovieSearchDelegate(
                        movies,
                        initialQuery: value,
                      ),
                    );
                  }
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
                  aspectRatio: 16 / 9,
                  autoPlayInterval: const Duration(seconds: 3),
                  viewportFraction: 0.8,
                ),
                items: nowShowing.take(5).map((movie) {
                  print(
                    'Loading carousel image for ${movie.title}: ${movie.posterUrl}',
                  );
                  return Builder(
                    builder: (BuildContext context) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/details',
                            arguments: movie,
                          );
                        },
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
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
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
                                // Gradient để chữ/điểm nhấn nổi trên poster
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                            letterSpacing: 0.2,
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Phim đang chiếu',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEDEDED),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: nowShowing.length,
                itemBuilder: (context, index) {
                  final movie = nowShowing[index];
                  print(
                    'Loading list image for ${movie.title}: ${movie.posterUrl}',
                  );
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: movie,
                              );
                            },
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
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: movie.posterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: CircularProgressIndicator(
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
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.55),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white12,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFFFC107),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${movie.rating.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                color: Color(0xFFEDEDED),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 50,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: movie,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Text(
                                movie.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Phim sắp chiếu',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEDEDED),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: comingSoon.length > 6 ? 6 : comingSoon.length,
                itemBuilder: (context, index) {
                  final movie = comingSoon[index];
                  print(
                    'Loading coming soon image for ${movie.title}: ${movie.posterUrl}',
                  );
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: movie,
                              );
                            },
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
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: movie,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Text(
                                movie.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
                },
              ),
            ),
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
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        backgroundColor: const Color(0xFF151521),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Delegate cho chức năng tìm kiếm (giữ nguyên không sửa)
class MovieSearchDelegate extends SearchDelegate<String> {
  final List<Movie> movies;
  final String initialQuery;

  MovieSearchDelegate(this.movies, {this.initialQuery = ''}) {
    query = initialQuery.isNotEmpty ? initialQuery : '';
    print('Khởi tạo MovieSearchDelegate với initialQuery: "$initialQuery"');
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Color(0xFFEDEDED)),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDED)),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filterMovies(query);
    print('Số kết quả tìm thấy: ${results.length} với query: "$query"');
    if (results.isEmpty && query.isNotEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy phim nào',
          style: TextStyle(fontSize: 18, color: Color(0xFFB9B9C3)),
        ),
      );
    }
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
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            ),
            errorWidget: (context, url, error) => Container(
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
            'Đạo diễn: ${movie.director} | Diễn viên: ${movie.actors.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB9B9C3)),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              movie.rating.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFFEDEDED),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onTap: () {
            Navigator.pushNamed(context, '/details', arguments: movie)
                .then((_) {
                  close(context, movie.title);
                })
                .catchError((error) {
                  print('Lỗi điều hướng: $error');
                });
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterMovies(query);
    print('Số gợi ý tìm thấy: ${suggestions.length} với query: "$query"');
    if (suggestions.isEmpty && query.isNotEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy gợi ý nào',
          style: TextStyle(fontSize: 18, color: Color(0xFFB9B9C3)),
        ),
      );
    }
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final movie = suggestions[index];
        return ListTile(
          tileColor: const Color(0xFF0B0B0F),
          leading: CachedNetworkImage(
            imageUrl: movie.posterUrl,
            width: 50,
            height: 75,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
            ),
            errorWidget: (context, url, error) => Container(
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
            'Đạo diễn: ${movie.director} | Diễn viên: ${movie.actors.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB9B9C3)),
          ),
          onTap: () {
            query = movie.title;
            showResults(context);
          },
        );
      },
    );
  }

  List<Movie> _filterMovies(String query) {
    print('Đang lọc với query: "$query"');
    if (query.isEmpty) return [];
    return movies.where((movie) {
      final titleLower = movie.title.toLowerCase();
      final directorLower = movie.director.toLowerCase();
      final actorsLower = movie.actors
          .map((actor) => actor.toLowerCase())
          .join(' ');
      final searchLower = query.toLowerCase();
      print(
        'Kiểm tra: $titleLower, $directorLower, $actorsLower chứa $searchLower?',
      );
      return titleLower.contains(searchLower) ||
          directorLower.contains(searchLower) ||
          actorsLower.contains(searchLower);
    }).toList();
  }
}
