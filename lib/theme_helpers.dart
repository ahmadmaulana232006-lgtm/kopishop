import 'package:flutter/material.dart';

BoxDecoration backgroundDecoration() {
  return BoxDecoration(
    image: DecorationImage(
      image: AssetImage('lib/images/baground.jpg'),
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(Colors.black26, BlendMode.darken),
    ),
  );
}

InputDecoration formInputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.brown[700]),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.95),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.brown.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.brown.shade700, width: 1.8),
    ),
  );
}
