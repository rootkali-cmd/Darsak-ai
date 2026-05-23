import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../core/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final student = auth.student;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  student.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(student.fullName, style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 20, fontWeight: FontWeight.bold)),
            Text(student.code, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 24),
            _buildInfoCard(student, data),
            const SizedBox(height: 16),
            _buildPinChangeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(dynamic student, DataProvider data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'رقم الهاتف', value: student.phone ?? '-'),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          _InfoRow(label: 'رقم ولي الأمر', value: student.parentPhone ?? '-'),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          _InfoRow(label: 'المستوى', value: student.gradeLevel ?? '-'),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          _InfoRow(label: 'حالة الدفع', value: data.isPaidThisMonth ? 'مدفوع' : 'غير مدفوع',
              valueColor: data.isPaidThisMonth ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          const Divider(color: Color(0xFF2A2A2A), height: 16),
          _InfoRow(label: 'متوسط الدرجات', value: '${data.averageGrade.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildPinChangeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تغيير PIN', style: TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPinChangeDialog(context),
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('تغيير الرقم السري'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinChangeDialog(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final api = ApiService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        title: const Text('تغيير PIN', style: TextStyle(color: Color(0xFFF5F5F5))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF5F5F5)),
              decoration: InputDecoration(
                labelText: 'PIN الحالي',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF5F5F5)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                _UpperCaseTextFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'PIN الجديد (6-8 أحرف وأرقام)',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF5F5F5)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                _UpperCaseTextFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'تأكيد PIN الجديد',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = newPinController.text.trim();
              final confirmPin = confirmPinController.text.trim();
              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN غير متطابق'), backgroundColor: Color(0xFFEF4444)));
                return;
              }
              if (newPin.length < 6 || newPin.length > 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN يجب أن يكون 6-8 أحرف وأرقام'), backgroundColor: Color(0xFFEF4444)));
                return;
              }
              try {
                await api.changePin(oldPinController.text.trim(), newPin);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير PIN بنجاح'), backgroundColor: Color(0xFF10B981)));
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().contains('401') ? 'PIN الحالي غير صحيح' : 'فشل تغيير PIN'),
                  backgroundColor: const Color(0xFFEF4444),
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: const Text('تسجيل الخروج', style: TextStyle(color: Color(0xFFF5F5F5))),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor ?? const Color(0xFFF5F5F5), fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
