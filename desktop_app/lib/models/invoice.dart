class InvoiceModel {
  final String id;
  final String studentId;
  final double amount;
  final String? description;
  final bool paid;
  final String? paymentDate;
  final String? signature;
  final DateTime createdAt;

  InvoiceModel({
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
      id: json['id'],
      studentId: json['student_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'],
      paid: json['paid'] ?? false,
      paymentDate: json['payment_date'],
      signature: json['signature'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
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
