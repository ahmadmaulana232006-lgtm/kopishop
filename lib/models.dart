class Coffee {
  final String id;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final int stock;

  Coffee({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.stock,
  });

  Coffee copyWith({
    String? id,
    String? name,
    int? price,
    String? description,
    String? imageUrl,
    int? stock,
  }) {
    return Coffee(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'stock': stock,
    };
  }

  factory Coffee.fromJson(Map<String, dynamic> json) {
    return Coffee(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      stock: json['stock'] as int,
    );
  }
}

class TransactionItem {
  final String id;
  final String name;
  final int price;
  final int quantity;
  final String imageUrl;

  TransactionItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  int get total => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int,
      imageUrl: json['imageUrl'] as String,
    );
  }
}

class TransactionRecord {
  final String id;
  final DateTime dateTime;
  final int total;
  final String type;
  final String paymentMethod;
  final String note;
  final List<TransactionItem> items;

  TransactionRecord({
    required this.id,
    required this.dateTime,
    required this.total,
    required this.type,
    required this.paymentMethod,
    required this.note,
    required this.items,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'total': total,
      'type': type,
      'paymentMethod': paymentMethod,
      'note': note,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      total: json['total'] as int,
      type: json['type'] as String,
      paymentMethod: json['paymentMethod'] as String,
      note: json['note'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => TransactionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
