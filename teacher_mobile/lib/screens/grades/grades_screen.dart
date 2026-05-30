import 'package:flutter/material.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade, size: 80, color: Color(0xFF6b7280)),
            SizedBox(height: 16),
            Text(
              'الدرجات والتقييم',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'سيتم عرض درجات الطلاب هنا بعد المزامنة',
              style: TextStyle(color: Color(0xFF6b7280), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
