import 'dart:convert';
import 'package:uuid/uuid.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String? isbn;
  final String? category;
  final String? publisher;
  final int totalCopies;
  final int availableCopies;
  final String? rackLocation;
  final DateTime addedAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.isbn,
    this.category,
    this.publisher,
    required this.totalCopies,
    required this.availableCopies,
    this.rackLocation,
    required this.addedAt,
  });

  factory Book.create({
    required String title,
    required String author,
    String? isbn,
    String? category,
    String? publisher,
    required int totalCopies,
    String? rackLocation,
  }) {
    return Book(
      id: const Uuid().v4(),
      title: title,
      author: author,
      isbn: isbn,
      category: category,
      publisher: publisher,
      totalCopies: totalCopies,
      availableCopies: totalCopies,
      rackLocation: rackLocation,
      addedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'publisher': publisher,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'rack_location': rackLocation,
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      isbn: map['isbn'] as String?,
      category: map['category'] as String?,
      publisher: map['publisher'] as String?,
      totalCopies: map['total_copies'] as int,
      availableCopies: map['available_copies'] as int,
      rackLocation: map['rack_location'] as String?,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory Book.fromJson(String source) =>
      Book.fromMap(json.decode(source) as Map<String, dynamic>);

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? isbn,
    String? category,
    String? publisher,
    int? totalCopies,
    int? availableCopies,
    String? rackLocation,
    DateTime? addedAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      category: category ?? this.category,
      publisher: publisher ?? this.publisher,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      rackLocation: rackLocation ?? this.rackLocation,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
