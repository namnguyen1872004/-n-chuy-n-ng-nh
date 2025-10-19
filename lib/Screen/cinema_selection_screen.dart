import 'package:flutter/material.dart';
import '../models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Đảm bảo import đúng

class CinemaSelectionScreen extends StatefulWidget {
  final Movie movie;
  final DateTime selectedDate;

  const CinemaSelectionScreen({
    super.key,
    required this.movie,
    required this.selectedDate,
  });

  @override
  State<CinemaSelectionScreen> createState() => _CinemaSelectionScreenState();
}

class _CinemaSelectionScreenState extends State<CinemaSelectionScreen> {
  int selectedCinemaIndex = 0;

  // Dữ liệu rạp có suất chiếu cho ngày đã chọn (giả lập)
  final List<Map<String, dynamic>> availableCinemas = [
    {
      'name': 'CGV Vincom Mega Mall',
      'address': 'Vincom Mega Mall Royal City, Thanh Xuân, Hà Nội',
      'distance': 2.5,
      'imageUrl': 'https://cdn.xanhsm.com/2025/02/bf178809-royal-city-5.jpg',
      'showtimes': ['10:00', '13:00', '16:00', '19:00', '22:00'],
    },
    {
      'name': 'Lotte Cinema Times City',
      'address': 'Times City, Hai Bà Trưng, Hà Nội',
      'distance': 1.8,
      'imageUrl':
          'https://img.tripi.vn/cdn-cgi/image/width=700,height=700/https://gcs.tripi.vn/public-tripi/tripi-feed/img/486420RoV/anh-mo-ta.png',
      'showtimes': ['9:30', '12:30', '15:30', '18:30', '21:30'],
    },
    {
      'name': 'BHD Star Cineplex Aeon Mall Hà Đông',
      'address': 'Aeon Mall Hà Đông, Hà Đông, Hà Nội',
      'distance': 3.2,
      'imageUrl':
          'https://www.bhdstar.vn/wp-content/uploads/2023/12/0000000009.png',
      'showtimes': ['11:00', '14:00', '17:00', '20:00', '23:00'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedCinema = availableCinemas[selectedCinemaIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.movie.title}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với thông tin ngày và phim
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn rạp',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.movie.title}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year} | ${widget.movie.genre}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danh sách rạp
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: availableCinemas.length,
              itemBuilder: (context, index) {
                final cinema = availableCinemas[index];
                final isSelected = index == selectedCinemaIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8B1E9B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          selectedCinemaIndex = index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Ảnh rạp
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: cinema['imageUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.location_city,
                                    color: Colors.grey,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.location_city,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Thông tin rạp
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cinema['name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    cinema['address'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${cinema['showtimes'].length} suất',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected
                                              ? Colors.white70
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.near_me,
                                            size: 14,
                                            color: isSelected
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${cinema['distance']} km',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black87,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Trở lại',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // Chuyển sang trang chọn giờ với rạp đã chọn
                      Navigator.pushNamed(
                        context,
                        '/time-selection',
                        arguments: {
                          'movie': widget.movie,
                          'date': widget.selectedDate,
                          'cinema': availableCinemas[selectedCinemaIndex],
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E9B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Chọn giờ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    );
  }
}
