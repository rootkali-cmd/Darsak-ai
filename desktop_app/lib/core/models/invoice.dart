class InvoiceModel {
  final String id;
  final String studentId;
  final double amount;
  final String? description;
  final bool paid;
  final String? paymentDate;
  final String? signature;
  final DateTime createdAt;

  const InvoiceModel({
    required this.id,
    required this.studentId,
    required this.amount,
    this.description,
    required this.paid,
    this.paymentDate,
    this.signature,
    required this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description']?.toString(),
      paid: json['paid'] ?? false,
      paymentDate: json['payment_date']?.toString(),
      signature: json['signature']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'amount': amount,
        'description': description,
        'paid': paid,
        'payment_date': paymentDate,
        'signature': signature,
        'created_at': createdAt.toIso8601String(),
      };
}
