import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class InvoicesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _invoices = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInvoices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await _api.getInvoices();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل الفواتير';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createInvoice(Map<String, dynamic> data) async {
    try {
      await _api.createInvoice(data);
      await loadInvoices();
      return true;
    } catch (e) {
      _error = 'فشل إضافة الفاتورة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateInvoice(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateInvoice(id, data);
      await loadInvoices();
      return true;
    } catch (e) {
      _error = 'فشل تحديث الفاتورة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInvoice(int id) async {
    try {
      await _api.deleteInvoice(id);
      _invoices.removeWhere((i) => i['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف الفاتورة';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      return await _api.getInvoiceStats();
    } catch (e) {
      return null;
    }
  }
}
