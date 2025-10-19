import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/snack_model.dart';

class SnackScreen extends StatefulWidget {
  const SnackScreen({super.key});

  @override
  State<SnackScreen> createState() => _SnackScreenState();
}

class _SnackScreenState extends State<SnackScreen> {
  String selectedCinemaId = '';
  String filter = 'Tất cả';
  String searchQuery = '';
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  final List<Snack> cartItems = [];
  int cartCount = 0;

  void addToCart(Snack snack) {
    setState(() {
      cartItems.add(snack);
      cartCount++;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã thêm ${snack.name} vào giỏ')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bắp Nước',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.black),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xem giỏ hàng (chưa hoàn thiện)'),
                    ),
                  );
                },
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Dropdown chọn rạp từ Firebase ---
          StreamBuilder<DatabaseEvent>(
            stream: _database.child('cinemas').onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Lỗi: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Không có dữ liệu rạp trong Firebase!'),
                );
              }

              final rawData = snapshot.data!.snapshot.value;
              Map<String, dynamic> cinemasMap = {};

              if (rawData is Map) {
                cinemasMap = Map<String, dynamic>.from(rawData);
              } else if (rawData is List) {
                for (int i = 0; i < rawData.length; i++) {
                  if (rawData[i] != null) {
                    cinemasMap[i.toString()] = Map<String, dynamic>.from(
                      rawData[i],
                    );
                  }
                }
              }

              if (selectedCinemaId.isEmpty && cinemasMap.isNotEmpty) {
                selectedCinemaId = cinemasMap.keys.first;
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButton<String>(
                  value: selectedCinemaId,
                  hint: const Text('Chọn rạp'),
                  items: cinemasMap.entries.map((entry) {
                    final cinemaData = Map<String, dynamic>.from(entry.value);
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(cinemaData['name'] ?? 'Không có tên'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedCinemaId = newValue;
                      });
                    }
                  },
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                ),
              );
            },
          ),

          // --- Ô tìm kiếm ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm bắp nước...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          // --- Bộ lọc ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 'Tất cả'),
                  _buildFilterChip('Khuyến mãi', 'Khuyến mãi'),
                  _buildFilterChip('Phổ biến', 'Phổ biến'),
                ],
              ),
            ),
          ),

          // --- Danh sách snack ---
          Expanded(
            child: selectedCinemaId.isEmpty
                ? const Center(child: Text('Hãy chọn một rạp để xem bắp nước'))
                : StreamBuilder<DatabaseEvent>(
                    stream: _database
                        .child('cinemas/$selectedCinemaId/snacks')
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Lỗi: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.snapshot.value == null) {
                        return const Center(
                          child: Text('Không có dữ liệu bắp nước'),
                        );
                      }

                      final rawData = snapshot.data!.snapshot.value;
                      Map<dynamic, dynamic> snacksMap = {};

                      if (rawData is Map) {
                        snacksMap = rawData;
                      } else if (rawData is List) {
                        for (int i = 0; i < rawData.length; i++) {
                          if (rawData[i] != null) {
                            snacksMap[i] = rawData[i];
                          }
                        }
                      }

                      final snacks = snacksMap.entries.map((entry) {
                        final snackData = Map<String, dynamic>.from(
                          entry.value,
                        );
                        return Snack(
                          id: snackData['id']?.toString() ?? '',
                          name: snackData['name']?.toString() ?? '',
                          price: (snackData['price'] ?? 0.0).toDouble(),
                          imageUrl: snackData['imageUrl']?.toString() ?? '',
                          description:
                              snackData['description']?.toString() ?? '',
                        );
                      }).toList();

                      // Lọc sản phẩm
                      final filteredSnacks = snacks.where((snack) {
                        final matchesFilter =
                            filter == 'Tất cả' ||
                            (filter == 'Khuyến mãi' && snack.price < 70.0) ||
                            (filter == 'Phổ biến' &&
                                snack.name.contains('Combo'));
                        final matchesSearch =
                            searchQuery.isEmpty ||
                            snack.name.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ) ||
                            snack.description.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            );
                        return matchesFilter && matchesSearch;
                      }).toList();

                      if (filteredSnacks.isEmpty) {
                        return const Center(
                          child: Text('Không có sản phẩm phù hợp'),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(8.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: filteredSnacks.length,
                        itemBuilder: (context, index) {
                          final snack = filteredSnacks[index];
                          return _buildSnackCard(snack);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (selected) {
          setState(() {
            filter = value;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: const Color(0xFF8B1E9B),
        labelStyle: TextStyle(
          fontSize: 12,
          color: filter == value ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildSnackCard(Snack snack) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: snack.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snack.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  snack.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${snack.price}k VNĐ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8B1E9B),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => addToCart(snack),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1E9B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Thêm', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
