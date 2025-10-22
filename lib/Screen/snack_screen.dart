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
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Bắp Nước',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Color(0xFFEDEDED)),
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
                      color: Color(0xFFEF4444),
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
                  child: Text(
                    'Lỗi: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFEDEDED)),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B1E9B)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Không có dữ liệu rạp trong Firebase!',
                    style: TextStyle(color: Color(0xFFB9B9C3)),
                  ),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF151521),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222230)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: selectedCinemaId,
                    hint: const Text(
                      'Chọn rạp',
                      style: TextStyle(color: Color(0xFFB9B9C3)),
                    ),
                    items: cinemasMap.entries.map((entry) {
                      final cinemaData = Map<String, dynamic>.from(entry.value);
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          cinemaData['name'] ?? 'Không có tên',
                          style: const TextStyle(color: Color(0xFFEDEDED)),
                        ),
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
                    style: const TextStyle(
                      color: Color(0xFFEDEDED),
                      fontSize: 16,
                    ),
                    dropdownColor: const Color(0xFF151521),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
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
              style: const TextStyle(color: Color(0xFFEDEDED)),
              cursorColor: const Color(0xFF8B1E9B),
              decoration: InputDecoration(
                hintText: 'Tìm bắp nước...',
                hintStyle: const TextStyle(color: Color(0xFFB9B9C3)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFB9B9C3)),
                filled: true,
                fillColor: const Color(0xFF151521),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF222230)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF222230)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B1E9B)),
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
                ? const Center(
                    child: Text(
                      'Hãy chọn một rạp để xem bắp nước',
                      style: TextStyle(color: Color(0xFFB9B9C3)),
                    ),
                  )
                : StreamBuilder<DatabaseEvent>(
                    stream: _database
                        .child('cinemas/$selectedCinemaId/snacks')
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Lỗi: ${snapshot.error}',
                            style: const TextStyle(color: Color(0xFFEDEDED)),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B1E9B),
                          ),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.snapshot.value == null) {
                        return const Center(
                          child: Text(
                            'Không có dữ liệu bắp nước',
                            style: TextStyle(color: Color(0xFFB9B9C3)),
                          ),
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
                          child: Text(
                            'Không có sản phẩm phù hợp',
                            style: TextStyle(color: Color(0xFFB9B9C3)),
                          ),
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
    final bool selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : const Color(0xFFEDEDED),
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: selected,
        onSelected: (s) {
          setState(() {
            filter = value;
          });
        },
        backgroundColor: const Color(0xFF151521),
        selectedColor: const Color(0xFF8B1E9B),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? const Color(0xFF8B1E9B) : const Color(0xFF222230),
          ),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildSnackCard(Snack snack) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151521),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222230)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                color: const Color(0xFF222230),
                child: const Icon(Icons.fastfood, color: Color(0xFFB9B9C3)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: const Color(0xFF222230),
                child: const Icon(Icons.fastfood, color: Color(0xFFB9B9C3)),
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
                    color: Color(0xFFEDEDED),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  snack.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB9B9C3),
                  ),
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
                        fontWeight: FontWeight.w600,
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
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
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
