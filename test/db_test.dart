import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/core/database/database_helper.dart';
import 'package:school_management_system/services/database_service.dart';
import 'package:school_management_system/models/models.dart';
import 'package:school_management_system/models/inventory.dart';
import 'package:school_management_system/models/book.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Create Book', () async {
    final dbHelper = DatabaseHelper();
    final dbService = DatabaseService(dbHelper: dbHelper);
    final book = Book.create(
      title: 'Test Book',
      author: 'Test Author',
      totalCopies: 1,
      rackLocation: 'A1',
    );
    await dbService.createBook(book);
    final books = await dbService.getAllBooks();
    expect(books.isNotEmpty, true);
  });

  test('Create Inventory Category and Item', () async {
    final dbHelper = DatabaseHelper();
    final dbService = DatabaseService(dbHelper: dbHelper);
    
    // Attempting to create an inventory item directly
    final item = InventoryItem(
      id: 'inv-1',
      name: 'Test Item',
      categoryId: 'cat-1',
      unit: 'piece',
      currentStock: 10,
      reorderThreshold: 5,
    );
    await dbService.createInventoryItem(item);
  });
}
