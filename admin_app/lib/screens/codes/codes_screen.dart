import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class CodesScreen extends StatefulWidget {
  const CodesScreen({super.key});

  @override
  State<CodesScreen> createState() => _CodesScreenState();
}

class _CodesScreenState extends State<CodesScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://darsak-backend.fly.dev/api/v1/admin',
    connectTimeout: const Duration(seconds: 30),
  ));

  String _selectedPlan = 'free';
  final _quantityController = TextEditingController(text: '1');
  bool _generating = false;
  List<Map<String, dynamic>> _codes = [];
  bool _loading = true;

  // Placeholder data
  static const _placeholderCodes = [
    {'id': '1', 'code': 'DSK-A1B2C3', 'plan_name': 'Free', 'is_used': true},
    {'id': '2', 'code': 'DSK-D4E5F6', 'plan_name': 'Premium', 'is_used': false},
  ];

  static const _plans = [
    {'name': 'Free', 'value': 'free'},
    {'name': 'Premium', 'value': 'premium'},
    {'name': 'Pro', 'value': 'pro'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCodes();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchCodes() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/codes');
      final list = List<Map<String, dynamic>>.from(res.data);
      if (mounted) setState(() { _codes = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _codes = _placeholderCodes; _loading = false; });
    }
  }

  Future<void> _generateCodes() async {
    final qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty < 1 || qty > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العدد يجب أن يكون بين 1 و 100')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      await _dio.post('/codes', data: {
        'plan': _selectedPlan,
        'quantity': qty,
      });
      await _fetchCodes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم توليد الأكواد')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل توليد الأكواد'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'توليد أكواد جديدة',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPlan,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.expand_more, color: Color(0xFFD4AF37)),
                            isExpanded: true,
                            items: _plans.map((plan) {
                              return DropdownMenuItem(
                                value: plan['value'],
                                child: Text(plan['name'] as String),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedPlan = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'العدد',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: const Color(0xFF0A0A0A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFB8941E)],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _generating ? null : _generateCodes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _generating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'توليد',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'الأكواد',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
                onPressed: _fetchCodes,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : RefreshIndicator(
                  onRefresh: _fetchCodes,
                  color: const Color(0xFFD4AF37),
                  child: _codes.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'لا توجد أكواد',
                                style: TextStyle(color: Colors.white30),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _codes.length,
                          itemBuilder: (context, index) {
                            final code = _codes[index];
                            final isUsed = code['is_used'] as bool;
                            return _codeCard(code, isUsed);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _codeCard(Map<String, dynamic> code, bool isUsed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code['code'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code['plan_name'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUsed ? Colors.redAccent.withValues(alpha: 0.4) : const Color(0xFFD4AF37).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              isUsed ? 'مستخدم' : 'متاح',
              style: TextStyle(
                color: isUsed ? Colors.redAccent : const Color(0xFFD4AF37),
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFFD4AF37), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code['code'] as String));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}
