import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'models.dart';

class CoffeeDetailPage extends StatelessWidget {
  final Coffee coffee;

  const CoffeeDetailPage({super.key, required this.coffee});

  // Helper function untuk format rupiah
  String _formatRupiah(dynamic harga) {
    try {
      final price = harga is int ? harga : int.parse(harga.toString());
      final formatter = price.toString();
      String result = '';
      int count = 0;
      for (int i = formatter.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) {
          result = '.$result';
        }
        result = '${formatter[i]}$result';
        count++;
      }
      return 'Rp $result';
    } catch (e) {
      return 'Rp ${harga.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFDF5FF),
      appBar: AppBar(
        title: Text(
          "Detail Menu",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner Gambar Kopi
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.brown[100],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: coffee.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: Image.asset(
                        coffee.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.coffee_maker,
                              size: 100,
                              color: Colors.brown[800],
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.coffee_maker,
                        size: 100,
                        color: Colors.brown[800],
                      ),
                    ),
            ),

            // Konten Detail
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Kopi dan Badge Harga
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          coffee.name,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown[900],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Badge Harga
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.brown[600],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (Colors.brown[700] ?? const Color(0xFF5D4037))
                                      .withValues(alpha: 0.8),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _formatRupiah(coffee.price),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),
                  Text(
                    coffee.stock > 0 ? 'Stok: ${coffee.stock}' : 'Stok Habis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: coffee.stock > 0
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),

                  SizedBox(height: 10),
                  // Divider
                  Container(height: 1, color: Colors.brown[200]),

                  SizedBox(height: 20),

                  // Label Deskripsi
                  Text(
                    "Deskripsi Rasa",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown[900],
                    ),
                  ),

                  SizedBox(height: 10),

                  // Deskripsi Rasa Kopi
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.brown[200]!, width: 1.5),
                    ),
                    child: Text(
                      coffee.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[700],
                        height: 1.6,
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Info Box dengan Detail Tambahan
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.brown[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.orange[600],
                              size: 28,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Hangat",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: Colors.red[400],
                              size: 28,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Premium",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber[600],
                              size: 28,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "4.9/5",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Tombol Pesan Sekarang
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: coffee.stock <= 0
                          ? null
                          : () {
                              final existingIndex = CartManager.cartItems
                                  .indexWhere(
                                    (item) => item['id'] == coffee.id,
                                  );
                              final currentQty = existingIndex != -1
                                  ? CartManager
                                            .cartItems[existingIndex]['quantity']
                                        as int
                                  : 0;
                              if (currentQty >= coffee.stock) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Tidak dapat menambah, stok ${coffee.name} hanya ${coffee.stock}.",
                                    ),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.red[600],
                                  ),
                                );
                                return;
                              }

                              CartManager.addToCart(
                                id: coffee.id,
                                name: coffee.name,
                                price: coffee.price,
                                description: coffee.description,
                                imageUrl: coffee.imageUrl,
                                quantity: 1,
                              );

                              // Tampilkan SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${coffee.name} berhasil ditambahkan ke keranjang!",
                                  ),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green[600],
                                ),
                              );

                              // Navigate ke CartPage
                              Navigator.pushNamed(context, '/cart');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: Colors.brown.withValues(alpha: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 22),
                          SizedBox(width: 10),
                          Text(
                            "Pesan Sekarang",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
