import 'package:flutter/material.dart';

class AdmissionQueueScreen extends StatefulWidget {
  const AdmissionQueueScreen({super.key});

  @override
  State<AdmissionQueueScreen> createState() => _AdmissionQueueScreenState();
}

class _AdmissionQueueScreenState extends State<AdmissionQueueScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('طلبات التسجيل'),
    );
  }
}
