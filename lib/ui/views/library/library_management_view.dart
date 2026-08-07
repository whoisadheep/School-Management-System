import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/services_provider.dart';

class LibraryManagementView extends ConsumerStatefulWidget {
  const LibraryManagementView({super.key});

  @override
  ConsumerState<LibraryManagementView> createState() => _LibraryManagementViewState();
}

class _LibraryManagementViewState extends ConsumerState<LibraryManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSurface,
        elevation: 0,
        title: const Text('Library Management', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryPurple,
          tabs: const [
            Tab(text: 'Catalog'),
            Tab(text: 'Issue Book'),
            Tab(text: 'Returns & Fines'),
            Tab(text: 'Overdue Books'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CatalogTab(),
          _IssueBookTab(),
          _ReturnsAndFinesTab(),
          _OverdueBooksTab(),
        ],
      ),
    );
  }
}

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab();

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(allBooksProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by title or author...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textHint),
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddBookDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: AppTheme.textOnPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Book'),
              ),
            ],
          ),
        ),
        Expanded(
          child: booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
            data: (books) {
              final filtered = books.where((b) {
                final titleMatch = b.title.toLowerCase().contains(_searchQuery);
                final authorMatch = b.author.toLowerCase().contains(_searchQuery);
                return titleMatch || authorMatch;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No books found.', style: TextStyle(color: AppTheme.textSecondary)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final book = filtered[index];
                  return Card(
                    color: AppTheme.bgSurface,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.divider),
                    ),
                    child: ListTile(
                      title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      subtitle: Text('${book.author} • ISBN: ${book.isbn ?? 'N/A'} • Rack: ${book.rackLocation ?? 'N/A'}\nAvailable: ${book.availableCopies} / ${book.totalCopies}'),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(book.category ?? 'Uncategorized'),
                        backgroundColor: AppTheme.primarySoft,
                        labelStyle: const TextStyle(color: AppTheme.primaryDark, fontSize: 12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddBookDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final totalCopiesCtrl = TextEditingController(text: '1');
    final rackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('Add New Book', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author')),
              TextField(controller: totalCopiesCtrl, decoration: const InputDecoration(labelText: 'Total Copies'), keyboardType: TextInputType.number),
              TextField(controller: rackCtrl, decoration: const InputDecoration(labelText: 'Rack Location')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final copies = int.tryParse(totalCopiesCtrl.text) ?? 1;
              final book = Book.create(
                title: titleCtrl.text,
                author: authorCtrl.text,
                totalCopies: copies,
                rackLocation: rackCtrl.text,
              );
              await ref.read(databaseServiceProvider).createBook(book);
              ref.invalidate(allBooksProvider);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Add', style: TextStyle(color: AppTheme.textOnPrimary)),
          ),
        ],
      ),
    );
  }
}

class _IssueBookTab extends ConsumerStatefulWidget {
  const _IssueBookTab();

  @override
  ConsumerState<_IssueBookTab> createState() => _IssueBookTabState();
}

class _IssueBookTabState extends ConsumerState<_IssueBookTab> {
  final _borrowerIdCtrl = TextEditingController();
  final _bookIdCtrl = TextEditingController();
  String _borrowerType = 'student';
  DateTime? _dueDate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: Card(
          color: AppTheme.bgSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Issue Book', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _borrowerType,
                  decoration: InputDecoration(
                    labelText: 'Borrower Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  ],
                  onChanged: (val) => setState(() => _borrowerType = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _borrowerIdCtrl,
                  decoration: InputDecoration(
                    labelText: 'Borrower ID',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bookIdCtrl,
                  decoration: InputDecoration(
                    labelText: 'Book ID',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Due Date', style: TextStyle(color: AppTheme.textSecondary)),
                  subtitle: Text(_dueDate != null ? "${_dueDate!.toLocal()}".split(' ')[0] : 'Select Date', style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryPurple),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _dueDate = date);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _dueDate == null || _borrowerIdCtrl.text.isEmpty || _bookIdCtrl.text.isEmpty
                      ? null
                      : () async {
                          try {
                            await ref.read(databaseServiceProvider).issueBook(
                                  _bookIdCtrl.text,
                                  _borrowerType,
                                  _borrowerIdCtrl.text,
                                  _dueDate!,
                                );
                            ref.invalidate(allBooksProvider);
                            ref.invalidate(activeBookIssuesProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book issued successfully')));
                              _borrowerIdCtrl.clear();
                              _bookIdCtrl.clear();
                              setState(() => _dueDate = null);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: AppTheme.errorLight))));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: AppTheme.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Issue Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturnsAndFinesTab extends ConsumerWidget {
  const _ReturnsAndFinesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(activeBookIssuesProvider);

    return issuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
      data: (issues) {
        if (issues.isEmpty) {
          return const Center(child: Text('No active book issues.', style: TextStyle(color: AppTheme.textSecondary)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: issues.length,
          itemBuilder: (context, index) {
            final issue = issues[index];
            final fineAmount = (issue['fine_amount'] as num?)?.toDouble() ?? 0.0;
            final finePaid = (issue['fine_paid'] as int?) == 1;

            return Card(
              color: AppTheme.bgSurface,
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Book: ${issue['book_title'] ?? issue['book_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        Chip(
                          label: Text(issue['status'] ?? 'Issued'),
                          backgroundColor: AppTheme.infoLight,
                          labelStyle: const TextStyle(color: AppTheme.info, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Borrower: ${issue['borrower_id']} (${issue['borrower_type']})', style: const TextStyle(color: AppTheme.textSecondary)),
                    Text('Due Date: ${issue['due_date']}', style: const TextStyle(color: AppTheme.textSecondary)),
                    if (fineAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Fine: \$${fineAmount.toStringAsFixed(2)} ${finePaid ? "(Paid)" : "(Unpaid)"}',
                          style: TextStyle(color: finePaid ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (fineAmount > 0 && !finePaid)
                          OutlinedButton(
                            onPressed: () async {
                              await ref.read(databaseServiceProvider).payFine(issue['id']);
                              ref.invalidate(activeBookIssuesProvider);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.warning,
                              side: const BorderSide(color: AppTheme.warning),
                            ),
                            child: const Text('Pay Fine'),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await ref.read(databaseServiceProvider).returnBook(issue['id']);
                            ref.invalidate(activeBookIssuesProvider);
                            ref.invalidate(allBooksProvider);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: AppTheme.textOnPrimary),
                          child: const Text('Return Book'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OverdueBooksTab extends ConsumerWidget {
  const _OverdueBooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueAsync = ref.watch(overdueBookIssuesProvider);

    return overdueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
      data: (issues) {
        if (issues.isEmpty) {
          return const Center(child: Text('No overdue books! 🎉', style: TextStyle(color: AppTheme.success, fontSize: 18)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: issues.length,
          itemBuilder: (context, index) {
            final issue = issues[index];
            return Card(
              color: AppTheme.errorLight,
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.error),
              ),
              child: ListTile(
                leading: const Icon(Icons.warning, color: AppTheme.error, size: 32),
                title: Text('Book: ${issue['book_title'] ?? issue['book_id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                subtitle: Text('Borrower: ${issue['borrower_id']}\nDue Date: ${issue['due_date']}', style: const TextStyle(color: AppTheme.textPrimary)),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
