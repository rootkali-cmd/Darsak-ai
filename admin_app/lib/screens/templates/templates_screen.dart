import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://darsak-backend.fly.dev/api/v1/admin',
    connectTimeout: const Duration(seconds: 30),
  ));

  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  // Placeholder data
  static const _placeholderTemplates = [
    {
      'id': '1',
      'type': 'sms_regex',
      'name': 'Vodafone Cash',
      'pattern': r'Vodafone Cash.*?(\d{11}).*?(\d+\.?\d*)\s?(EGP|LE|ج\.م)',
    },
    {
      'id': '2',
      'type': 'sms_regex',
      'name': 'بنك مصر',
      'pattern': r'بنك مصر.*?(\d{11}).*?(\d+\.?\d*)\s?(EGP|LE|ج\.م)',
    },
    {
      'id': '3',
      'type': 'notification',
      'name': 'تنبيه دفع جديد',
      'pattern': 'تم استلام {amount} ج.م من {phone}',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/templates');
      final list = List<Map<String, dynamic>>.from(res.data);
      if (mounted) setState(() { _templates = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _templates = _placeholderTemplates; _loading = false; });
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final nameController = TextEditingController(text: template['name'] as String);
    final patternController = TextEditingController(text: template['pattern'] as String);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'تعديل القالب',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _dialogInputDecoration('الاسم'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: patternController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              decoration: _dialogInputDecoration('النمط'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameController.text,
              'pattern': patternController.text,
            }),
            child: const Text('حفظ', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await _dio.put('/templates/${template['id']}', data: result);
      _fetchTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل الحفظ'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
        : RefreshIndicator(
            onRefresh: _fetchTemplates,
            color: const Color(0xFFD4AF37),
            child: _templates.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'لا توجد قوالب',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final tpl = _templates[index];
                      return _templateCard(tpl);
                    },
                  ),
          );
  }

  Widget _templateCard(Map<String, dynamic> tpl) {
    final type = tpl['type'] as String;
    final isRegex = type == 'sms_regex';

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isRegex
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.15),
            ),
            child: Text(
              isRegex ? 'SMS' : 'إشعار',
              style: TextStyle(
                color: isRegex ? const Color(0xFFD4AF37) : Colors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tpl['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tpl['pattern'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFD4AF37), size: 20),
            onPressed: () => _editTemplate(tpl),
          ),
        ],
      ),
    );
  }
}
