import 'dart:convert';
import 'package:uuid/uuid.dart';

class BookIssue {
  final String id;
  final String bookId;
  final String borrowerType;
  final String borrowerId;
  final DateTime issueDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final double fineAmount;
  final bool finePaid;
  final String status;

  const BookIssue({
    required this.id,
    required this.bookId,
    required this.borrowerType,
    required this.borrowerId,
    required this.issueDate,
    required this.dueDate,
    this.returnDate,
    this.fineAmount = 0.0,
    this.finePaid = false,
    required this.status,
  });

  factory BookIssue.create({
    required String bookId,
    required String borrowerType,
    required String borrowerId,
    required DateTime dueDate,
  }) {
    return BookIssue(
      id: const Uuid().v4(),
      bookId: bookId,
      borrowerType: borrowerType,
      borrowerId: borrowerId,
      issueDate: DateTime.now(),
      dueDate: dueDate,
      status: 'issued',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'borrower_type': borrowerType,
      'borrower_id': borrowerId,
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'fine_amount': fineAmount,
      'fine_paid': finePaid ? 1 : 0,
      'status': status,
    };
  }

  factory BookIssue.fromMap(Map<String, dynamic> map) {
    return BookIssue(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      borrowerType: map['borrower_type'] as String,
      borrowerId: map['borrower_id'] as String,
      issueDate: DateTime.parse(map['issue_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      returnDate: map['return_date'] != null ? DateTime.parse(map['return_date'] as String) : null,
      fineAmount: (map['fine_amount'] as num).toDouble(),
      finePaid: (map['fine_paid'] as int) == 1,
      status: map['status'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory BookIssue.fromJson(String source) =>
      BookIssue.fromMap(json.decode(source) as Map<String, dynamic>);

  BookIssue copyWith({
    String? id,
    String? bookId,
    String? borrowerType,
    String? borrowerId,
    DateTime? issueDate,
    DateTime? dueDate,
    DateTime? returnDate,
    double? fineAmount,
    bool? finePaid,
    String? status,
  }) {
    return BookIssue(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      borrowerType: borrowerType ?? this.borrowerType,
      borrowerId: borrowerId ?? this.borrowerId,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      fineAmount: fineAmount ?? this.fineAmount,
      finePaid: finePaid ?? this.finePaid,
      status: status ?? this.status,
    );
  }
}
