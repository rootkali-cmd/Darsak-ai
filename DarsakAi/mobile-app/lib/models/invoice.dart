class InvoiceModel {
  final String id;
  final double amount;
  final String? description;
  final bool paid;
  final String? paymentDate;
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.amount,
    this.description,
    required this.paid,
    this.paymentDate,
    required this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toLowerCase() ?? '';
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'],
      paid: json['paid'] == true || status == 'paid' || status == 'approved',
      paymentDate: json['payment_date'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get month {
    final m = createdAt.month.toString().padLeft(2, '0');
    return '${createdAt.year}-$m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'description': description,
        'paid': paid,
        'payment_date': paymentDate,
        'created_at': createdAt.toIso8601String(),
      };
}
