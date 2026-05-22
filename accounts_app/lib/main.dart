import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'core/local_sync/local_sync_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const accountsDbPath = '/home/ahmed/Documents/DarsakAi/darsak_accounts_db';
  const mainDbPath = '/home/ahmed/Documents/DarsakAi/darsak_db';

  // Ensure accounts DB directory exists
  final accountsDir = Directory(accountsDbPath);
  if (!await accountsDir.exists()) await accountsDir.create(recursive: true);

  await Hive.initFlutter(accountsDbPath);

  // Try to sync students from main app DB
  await _syncStudentsFromMain(mainDbPath, accountsDbPath);

  await Hive.openBox<Map>('students');
  await Hive.openBox<Map>('payments');
  await Hive.openBox<Map>('settings');

  // Start local sync client
  final syncClient = LocalSyncClient();
  syncClient.connect();

  runApp(DarsakAccountsApp(syncClient: syncClient));
}

Future<void> _backupDb(String accountsDbPath) async {
  final backupDir = Directory('/home/ahmed/Documents/DarsakAi/darsak_accounts_db_backups');
  if (!await backupDir.exists()) await backupDir.create(recursive: true);
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final destDir = Directory('${backupDir.path}/backup_$timestamp');
  await destDir.create(recursive: true);
  final srcDir = Directory(accountsDbPath);
  if (await srcDir.exists()) {
    await for (final entity in srcDir.list()) {
      if (entity is File) {
        await entity.copy('${destDir.path}/${entity.uri.pathSegments.last}');
      }
    }
  }
}

Future<void> _syncStudentsFromMain(String mainDbPath, String accountsDbPath) async {
  try {
    final mainDir = Directory(mainDbPath);
    if (!await mainDir.exists()) return;

    final mainBox = await Hive.openBox<Map>('students', path: mainDbPath);
    if (mainBox.isEmpty) {
      await mainBox.close();
      return;
    }

    // Backup before syncing
    await _backupDb(accountsDbPath);

    // Copy to accounts Hive box
    final localBox = await Hive.openBox<Map>('students');
    localBox.clear();
    for (final entry in mainBox.toMap().entries) {
      await localBox.put(entry.key, Map<String, dynamic>.from(entry.value as Map));
    }

    await mainBox.close();
  } catch (_) {
    // Main DB is locked (main app running), use cached/empty data  
  }
}

class DarsakAccountsApp extends StatelessWidget {
  final LocalSyncClient syncClient;
  const DarsakAccountsApp({super.key, required this.syncClient});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccountsProvider(syncClient),
      child: MaterialApp(
        title: 'DarsakAI Accounts',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.dark),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: const AccountsHome(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7FA),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF2563EB),
        onPrimary: Colors.white,
        secondary: const Color(0xFF3B82F6),
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
        onSurface: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A2E),
      ),
      cardColor: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
      dividerColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E5EA),
    );
  }
}

class AccountsProvider extends ChangeNotifier {
  final LocalSyncClient _syncClient;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _payments = [];
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  List<Map<String, dynamic>> get students => _students;
  List<Map<String, dynamic>> get payments => _payments;
  String get selectedMonth => _selectedMonth;

  AccountsProvider(this._syncClient) {
    _syncClient.onEvent.listen((event) {
      loadData();
    });
  }

  void loadData() {
    _students = Hive.box<Map>('students').values.map((e) => Map<String, dynamic>.from(e)).toList();
    _payments = Hive.box<Map>('payments').values.map((e) => Map<String, dynamic>.from(e)).toList();
    notifyListeners();
  }

  void setMonth(String month) {
    _selectedMonth = month;
    notifyListeners();
  }

  Map<String, dynamic>? getPayment(String studentCode) {
    final key = '${studentCode}_$_selectedMonth';
    final data = Hive.box<Map>('payments').get(key);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> togglePayment(String studentCode) async {
    final key = '${studentCode}_$_selectedMonth';
    final box = Hive.box<Map>('payments');
    final existing = box.get(key);
    Map<String, dynamic> paymentData;
    if (existing != null) {
      existing['is_paid'] = !(existing['is_paid'] ?? false);
      existing['payment_date'] = DateTime.now().toIso8601String();
      existing['updated_at'] = DateTime.now().toIso8601String();
      paymentData = Map<String, dynamic>.from(existing);
      await box.put(key, paymentData);
    } else {
      paymentData = {
        'student_code': studentCode,
        'month': _selectedMonth,
        'is_paid': true,
        'payment_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await box.put(key, paymentData);
    }
    loadData();

    // Send event to desktop via local sync
    _syncClient.sendPaymentEvent(
      studentCode: studentCode,
      month: _selectedMonth,
      paymentData: paymentData,
    );
  }

  Future<void> setPaymentAmount(String studentCode, double amount) async {
    final key = '${studentCode}_$_selectedMonth';
    final box = Hive.box<Map>('payments');
    final existing = box.get(key) ?? <String, dynamic>{};
    existing['amount'] = amount;
    existing['student_code'] = studentCode;
    existing['month'] = _selectedMonth;
    existing['updated_at'] = DateTime.now().toIso8601String();
    final paymentData = Map<String, dynamic>.from(existing);
    await box.put(key, paymentData);
    loadData();

    // Send event to desktop via local sync
    _syncClient.sendPaymentEvent(
      studentCode: studentCode,
      month: _selectedMonth,
      paymentData: paymentData,
    );
  }

  List<Map<String, dynamic>> getUnpaidStudents() {
    return _students.where((s) {
      final key = '${s['code']}_$_selectedMonth';
      final payment = Hive.box<Map>('payments').get(key);
      return payment == null || payment['is_paid'] != true;
    }).toList();
  }

  double get totalCollected {
    double total = 0;
    for (final p in _payments) {
      if (p['is_paid'] == true && p['month'] == _selectedMonth) {
        total += (p['amount'] ?? 0).toDouble();
      }
    }
    return total;
  }
}

class AccountsHome extends StatefulWidget {
  const AccountsHome({super.key});

  @override
  State<AccountsHome> createState() => _AccountsHomeState();
}

class _AccountsHomeState extends State<AccountsHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountsProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountsProvider>();
    final students = provider.students;
    final unpaid = provider.getUnpaidStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الحسابات - درسك AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadData(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildSummaryBar(provider),
                Expanded(child: _buildPaymentList(provider, students)),
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: _buildUnpaidSidebar(provider, unpaid),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(AccountsProvider provider) {
    final total = provider.totalCollected;
    final unpaid = provider.getUnpaidStudents().length;
    final totalStudents = provider.students.length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _StatCard(label: 'إجمالي الطلاب', value: '$totalStudents', icon: Icons.people, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          _StatCard(label: 'المدفوع هذا الشهر', value: '${total.toStringAsFixed(0)} ج', icon: Icons.check_circle, color: const Color(0xFF10B981)),
          const SizedBox(width: 12),
          _StatCard(label: 'غير المدفوع', value: '$unpaid', icon: Icons.warning, color: const Color(0xFFEF4444)),
          const Spacer(),
          _MonthSelector(provider: provider),
        ],
      ),
    );
  }

  Widget _buildPaymentList(AccountsProvider provider, List<Map<String, dynamic>> students) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            const SizedBox(height: 8),
            Text('أضف طلاباً من النظام الأساسي أولاً', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index];
        final payment = provider.getPayment(s['code']);
        final isPaid = payment != null && payment['is_paid'] == true;
        final amount = payment != null ? (payment['amount'] ?? 0).toDouble() : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.3) : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    (s['full_name']?.toString().isNotEmpty == true ? s['full_name'][0] : '?'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['full_name'] ?? '-', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('${s['code'] ?? ''} - ${s['group_id']?.toString().isNotEmpty == true ? 'مجموعة' : 'بدون مجموعة'}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'المبلغ',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  controller: TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : ''),
                  onSubmitted: (v) => provider.setPaymentAmount(s['code'], double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => provider.togglePayment(s['code']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      isPaid ? 'مدفوع' : 'غير مدفوع',
                      style: TextStyle(
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnpaidSidebar(AccountsProvider provider, List<Map<String, dynamic>> unpaid) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 8),
                Text('غير المدفوعين ($unpaid)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: unpaid.isEmpty
                ? Center(child: Text('الكل مدفوع', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: unpaid.length,
                    itemBuilder: (context, index) {
                      final s = unpaid[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Text(s['full_name'] ?? '-', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                            const Spacer(),
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final AccountsProvider provider;

  const _MonthSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year, now.month),
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          provider.setMonth(DateFormat('yyyy-MM').format(picked));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(provider.selectedMonth, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }
}
