import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import "../../../core/auth/permission_helper.dart";
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inventory.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/auth_provider.dart';

class InventoryManagementView extends ConsumerStatefulWidget {
  const InventoryManagementView({super.key});

  @override
  ConsumerState<InventoryManagementView> createState() => _InventoryManagementViewState();
}

class _InventoryManagementViewState extends ConsumerState<InventoryManagementView> with SingleTickerProviderStateMixin {
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
    return Container(
      color: AppTheme.bgMain,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabBar(),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CatalogTab(),
                _StockEntryTab(),
                _LowStockAlertsTab(),
                _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: AppTheme.primaryPurple,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Catalog'),
          Tab(text: 'Stock Entry'),
          Tab(text: 'Low Stock Alerts'),
          Tab(text: 'History'),
        ],
      ),
    );
  }
}

class _CatalogTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider(_selectedCategoryId));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCategoryId,
                        hint: Text('All Categories', style: GoogleFonts.poppins()),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Categories', style: GoogleFonts.poppins()),
                          ),
                          ...categories.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name, style: GoogleFonts.poppins()),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        },
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading categories', style: GoogleFonts.poppins(color: AppTheme.error)),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddEditItemDialog(context, null),
              icon: const Icon(Icons.add),
              label: Text('Add Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: AppTheme.cardDecoration(),
            child: itemsAsync.when(
              data: (items) {
                final query = _searchController.text.toLowerCase();
                final filtered = items.where((i) => i.name.toLowerCase().contains(query)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No items found.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.divider),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isLowStock = item.currentStock <= item.reorderThreshold;

                    return ListTile(
                      title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Location: ${item.storageLocation ?? "N/A"} • Cost: \$${item.unitCost?.toStringAsFixed(2) ?? "N/A"}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isLowStock ? AppTheme.errorLight : AppTheme.successLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item.currentStock} ${item.unit}',
                              style: GoogleFonts.poppins(
                                color: isLowStock ? AppTheme.error : AppTheme.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppTheme.info),
                            onPressed: () => _showAddEditItemDialog(context, item),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddEditItemDialog(BuildContext context, InventoryItem? item) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.name);
    final unitCtrl = TextEditingController(text: item?.unit);
    final currentStockCtrl = TextEditingController(text: item?.currentStock.toString() ?? '0');
    final reorderThresholdCtrl = TextEditingController(text: item?.reorderThreshold.toString() ?? '5');
    final unitCostCtrl = TextEditingController(text: item?.unitCost?.toString());
    final locationCtrl = TextEditingController(text: item?.storageLocation);

    String? categoryId = item?.categoryId;
    final categories = ref.read(inventoryCategoriesProvider).valueOrNull ?? [];

    if (categoryId == null && categories.isNotEmpty) {
      categoryId = categories.first.id;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Item' : 'Add Item', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setStateDialog(() => categoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unitCtrl.text.isEmpty ? 'piece' : unitCtrl.text,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(value: 'piece', child: Text('Piece')),
                      DropdownMenuItem(value: 'box', child: Text('Box')),
                      DropdownMenuItem(value: 'kg', child: Text('Kg')),
                      DropdownMenuItem(value: 'litre', child: Text('Litre')),
                      DropdownMenuItem(value: 'set', child: Text('Set')),
                    ],
                    onChanged: (v) => setStateDialog(() => unitCtrl.text = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: currentStockCtrl, decoration: const InputDecoration(labelText: 'Current Stock'), keyboardType: TextInputType.number, enabled: !isEdit),
                  const SizedBox(height: 12),
                  TextField(controller: reorderThresholdCtrl, decoration: const InputDecoration(labelText: 'Reorder Threshold'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: unitCostCtrl, decoration: const InputDecoration(labelText: 'Unit Cost (Optional)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Storage Location (Optional)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || unitCtrl.text.isEmpty || categoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Category, and Unit are required')));
                  return;
                }
                try {
                  final newItem = InventoryItem(
                    id: isEdit ? item.id : const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    categoryId: categoryId!,
                    unit: unitCtrl.text.trim(),
                    currentStock: double.tryParse(currentStockCtrl.text) ?? 0,
                    reorderThreshold: double.tryParse(reorderThresholdCtrl.text) ?? 5,
                    unitCost: double.tryParse(unitCostCtrl.text),
                    storageLocation: locationCtrl.text.trim(),
                  );

                  if (isEdit) {
                    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                    await ref.read(databaseServiceProvider).updateInventoryItem(newItem);
                  } else {
                    await ref.read(databaseServiceProvider).createInventoryItem(newItem);
                  }
                  ref.invalidate(inventoryItemsProvider);
                  ref.invalidate(lowStockItemsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
              child: const Text('Save', style: TextStyle(color: AppTheme.textOnPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockEntryTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StockEntryTab> createState() => _StockEntryTabState();
}

class _StockEntryTabState extends ConsumerState<_StockEntryTab> {
  String? _selectedItemId;
  String _transactionType = 'purchase';
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  String? _issuedToType;
  final TextEditingController _issuedToIdCtrl = TextEditingController();
  
  bool _isLoading = false;

  final List<String> _txTypes = ['purchase', 'issue', 'return', 'adjustment', 'damage'];

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider(null));

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('No items in catalog. Add items first.', style: GoogleFonts.poppins()));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record Stock Transaction', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  value: _selectedItemId,
                  decoration: const InputDecoration(labelText: 'Select Item', border: OutlineInputBorder()),
                  hint: const Text('Select an item'),
                  items: items.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (Stock: ${i.currentStock})'))).toList(),
                  onChanged: (v) => setState(() => _selectedItemId = v),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _transactionType,
                  decoration: const InputDecoration(labelText: 'Transaction Type', border: OutlineInputBorder()),
                  items: _txTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() {
                    _transactionType = v!;
                    if (_transactionType != 'issue') {
                      _issuedToType = null;
                      _issuedToIdCtrl.clear();
                    }
                  }),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                if (_transactionType == 'issue') ...[
                  DropdownButtonFormField<String>(
                    value: _issuedToType,
                    decoration: const InputDecoration(labelText: 'Issued To Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'class', child: Text('Class')),
                      DropdownMenuItem(value: 'department', child: Text('Department')),
                    ],
                    onChanged: (v) => setState(() => _issuedToType = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _issuedToIdCtrl,
                    decoration: const InputDecoration(labelText: 'Issued To ID (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Record Transaction', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _submit() async {
    if (_selectedItemId == null || _qtyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an item and enter quantity')));
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final auth = ref.read(authProvider);
      
      final tx = StockTransaction(
        id: const Uuid().v4(),
        itemId: _selectedItemId!,
        transactionType: _transactionType,
        quantity: qty,
        issuedToType: _issuedToType,
        issuedToId: _issuedToIdCtrl.text.isEmpty ? null : _issuedToIdCtrl.text,
        transactionDate: DateTime.now().toIso8601String(),
        remarks: _remarksCtrl.text,
        recordedBy: auth.currentUser?.id ?? 'system',
      );

      await dbService.recordStockTransaction(tx);
      
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(lowStockItemsProvider);
      ref.invalidate(itemTransactionHistoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction recorded successfully'), backgroundColor: AppTheme.success));
        setState(() {
          _qtyCtrl.clear();
          _remarksCtrl.clear();
          _issuedToIdCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _LowStockAlertsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(lowStockItemsProvider);

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: alertsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
                  const SizedBox(height: 16),
                  Text('All items are sufficiently stocked.', style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Needs Reordering', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.error)),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.divider),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.errorLight,
                        child: Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                      ),
                      title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: Text('Threshold: ${item.reorderThreshold} ${item.unit}', style: GoogleFonts.poppins()),
                      trailing: Text(
                        'Current: ${item.currentStock} ${item.unit}',
                        style: GoogleFonts.poppins(color: AppTheme.error, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  String? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider(null));
    final historyAsync = ref.watch(itemTransactionHistoryProvider(_selectedItemId));

    return Column(
      children: [
        Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: itemsAsync.when(
            data: (items) {
              return DropdownButtonFormField<String>(
                value: _selectedItemId,
                decoration: const InputDecoration(labelText: 'Filter by Item', border: OutlineInputBorder()),
                hint: const Text('Select an item to view history'),
                items: items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                onChanged: (v) => setState(() => _selectedItemId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading items'),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: AppTheme.cardDecoration(),
            child: _selectedItemId == null
                ? Center(child: Text('Please select an item to view its transaction history.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)))
                : historyAsync.when(
                    data: (txs) {
                      if (txs.isEmpty) {
                        return Center(child: Text('No transactions found for this item.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: txs.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.divider),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          final date = DateTime.tryParse(tx.transactionDate);
                          final dateStr = date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : tx.transactionDate;
                          
                          final isAddition = tx.transactionType == 'purchase' || tx.transactionType == 'return' || (tx.transactionType == 'adjustment' && tx.quantity > 0);
                          final color = isAddition ? AppTheme.success : AppTheme.error;
                          final prefix = isAddition ? '+' : '-';

                          return ListTile(
                            title: Text(tx.transactionType.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Date: $dateStr\nRemarks: ${tx.remarks ?? "N/A"}',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            trailing: Text(
                              '$prefix${tx.quantity}',
                              style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
          ),
        ),
      ],
    );
  }
}
