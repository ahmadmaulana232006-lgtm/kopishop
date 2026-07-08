class CartManager {
  static final List<Map<String, dynamic>> cartItems = [];

  static void addToCart({
    required String id,
    required String name,
    required int price,
    required String description,
    required String imageUrl,
    int quantity = 1,
  }) {
    final index = cartItems.indexWhere((item) => item['id'] == id);
    if (index != -1) {
      cartItems[index]['quantity'] += quantity;
    } else {
      cartItems.add({
        'id': id,
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'quantity': quantity,
      });
    }
  }

  static void removeFromCart(String id) {
    cartItems.removeWhere((item) => item['id'] == id);
  }

  static void clearCart() {
    cartItems.clear();
  }

  static int totalPrice() {
    return cartItems.fold(0, (sum, item) {
      final price = item['price'] as int;
      final quantity = item['quantity'] as int;
      return sum + price * quantity;
    });
  }
}
