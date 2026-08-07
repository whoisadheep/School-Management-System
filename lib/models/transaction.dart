import 'package:uuid/uuid.dart';

enum PaymentMethod {
  cash,
  bankTransfer,
  cheque,
  online,
  other;

  String get dbValue {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.cheque:
        return 'cheque';
      case PaymentMethod.online:
        return 'online';
      case PaymentMethod.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.online:
        return 'Online / UPI';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'cheque':
        return PaymentMethod.cheque;
      case 'online':
        return PaymentMethod.online;
      default:
        return PaymentMethod.other;
    }
  }
}

class Transaction {
  final String id;
  final String invoiceId;
  final double amountPaid;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.invoiceId,
    required this.amountPaid,
    required this.paymentMethod,
    this.referenceNumber,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.create({
    required String invoiceId,
    required double amountPaid,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
  }) {
    final now = DateTime.now();
    return Transaction(
      id: const Uuid().v4(),
      invoiceId: invoiceId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      timestamp: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      amountPaid: (map['amount_paid'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromString(map['payment_method'] as String),
      referenceNumber: map['reference_number'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod.dbValue,
      'reference_number': referenceNumber,
      'timestamp': timestamp.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
