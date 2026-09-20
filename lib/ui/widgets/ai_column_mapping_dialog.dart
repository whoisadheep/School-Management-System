import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../services/column_mapping_service.dart';
import 'thinking_orb_widget.dart';

/// A full-screen dialog that shows AI-suggested column mappings
/// with dropdowns so the user can review & override before importing.
///
/// Returns the confirmed [List<ColumnMapping>] on "Confirm & Import",
/// or null if the user cancels.
class AIColumnMappingDialog extends StatefulWidget {
  final List<ColumnMapping> mappings;
  final List<String> sampleRow;
  final int totalRows;
  final ImportEntityType entityType;

  final String? providerName;
  final String? model;

  const AIColumnMappingDialog({
    super.key,
    required this.mappings,
    required this.sampleRow,
    required this.totalRows,
    this.entityType = ImportEntityType.student,
    this.providerName,
    this.model,
  });

  /// Show the dialog. Returns confirmed mappings or null if cancelled.
  static Future<List<ColumnMapping>?> show({
    required BuildContext context,
    required List<ColumnMapping> mappings,
    required List<String> sampleRow,
    required int totalRows,
    ImportEntityType entityType = ImportEntityType.student,
    String? providerName,
    String? model,
  }) {
    return showDialog<List<ColumnMapping>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AIColumnMappingDialog(
        mappings: mappings,
        sampleRow: sampleRow,
        totalRows: totalRows,
        entityType: entityType,
        providerName: providerName,
        model: model,
      ),
    );
  }

  @override
  State<AIColumnMappingDialog> createState() => _AIColumnMappingDialogState();
}

class _AIColumnMappingDialogState extends State<AIColumnMappingDialog> {
  late List<ColumnMapping> _mappings;
  bool _autoGenerateId = false;

  @override
  void initState() {
    super.initState();
    _mappings = List.from(widget.mappings);

    // Check if any column is mapped to the entity's ID field
    final idFieldKey = widget.entityType == ImportEntityType.staff ? 'staff_code' : 'admission_number';
    final hasIdMapping = _mappings.any((m) => m.eduviaFieldKey == idFieldKey);
    _autoGenerateId = !hasIdMapping;
  }

  int get _mappedCount => _mappings.where((m) => m.eduviaFieldKey != 'skip').length;
  int get _skippedCount => _mappings.where((m) => m.eduviaFieldKey == 'skip').length;
  bool get _hasFirstName => _mappings.any((m) => m.eduviaFieldKey == 'first_name' || m.eduviaFieldKey == 'full_name');
  bool get _hasClass => _mappings.any((m) => m.eduviaFieldKey == 'class');
  bool get _isValid => widget.entityType == ImportEntityType.staff ? _hasFirstName : (_hasFirstName && _hasClass);

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF16A34A);
    if (confidence >= 0.5) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String _confidenceLabel(double confidence) {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    if (confidence > 0) return 'Low';
    return 'Unmapped';
  }

  IconData _confidenceIcon(double confidence) {
    if (confidence >= 0.8) return Icons.check_circle_rounded;
    if (confidence >= 0.5) return Icons.help_rounded;
    return Icons.warning_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppTheme.bgMain,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel Import',
            onPressed: () => Navigator.of(context).pop(null),
          ),
          title: Row(
            children: [
              const EduviaThinkingOrb(
                size: 22,
                state: OrbState.connecting,
                showGlow: false,
                theme: OrbTheme.dark,
              ),
              const SizedBox(width: 10),
              Text(
                'AI Smart Column Mapper',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _isValid
                    ? () => Navigator.of(context).pop(_mappings)
                    : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Confirm & Import ${widget.totalRows} ${widget.entityType == ImportEntityType.staff ? 'Staff' : 'Students'}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryPurple,
                  disabledBackgroundColor: Colors.white38,
                  disabledForegroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Stats Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  if (widget.providerName != null) ...[
                    _buildStatChip(
                      Icons.auto_awesome_rounded,
                      widget.model != null ? '${widget.providerName} (${widget.model})' : widget.providerName!,
                      const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 16),
                  ],
                  _buildStatChip(Icons.check_circle_rounded, '$_mappedCount Mapped', const Color(0xFF16A34A)),
                  const SizedBox(width: 16),
                  _buildStatChip(Icons.skip_next_rounded, '$_skippedCount Skipped', AppTheme.textSecondary),
                  const SizedBox(width: 16),
                  _buildStatChip(Icons.table_rows_rounded, '${widget.totalRows} Rows', AppTheme.primaryPurple),
                  const Spacer(),
                  // Auto-generate ID toggle
                  Row(
                    children: [
                      Text(
                        widget.entityType == ImportEntityType.staff
                            ? 'Auto-generate Employee ID (EMP-YYYY-XXX)'
                            : 'Auto-generate Admission No. (0001, 0002...)',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _autoGenerateId,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) {
                          setState(() {
                            _autoGenerateId = val;
                            if (val) {
                              final targetKey = widget.entityType == ImportEntityType.staff ? 'staff_code' : 'admission_number';
                              for (final m in _mappings) {
                                if (m.eduviaFieldKey == targetKey) {
                                  m.eduviaFieldKey = 'skip';
                                }
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Validation warnings
            if (!_isValid)
              Container(
                width: double.infinity,
                color: const Color(0xFFFEF3C7),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      widget.entityType == ImportEntityType.staff
                          ? 'Required: Map at least "First Name" (or "Full Name") to import staff.'
                          : (!_hasFirstName && !_hasClass)
                              ? 'Required: Map at least "First Name" (or "Full Name") and "Class / Grade" to import.'
                              : !_hasFirstName
                                  ? 'Required: Map a column to "First Name" or "Full Name".'
                                  : 'Required: Map a column to "Class / Grade".',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            // Privacy Notice
            Container(
              width: double.infinity,
              color: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '🔒 Only column headers were sent to AI — zero ${widget.entityType == ImportEntityType.staff ? 'staff' : 'student'} data was shared.',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Mapping Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            _tableHeader('Your File Column', flex: 3),
                            _tableHeader('Sample Data', flex: 3),
                            _tableHeader('AI Confidence', flex: 2),
                            _tableHeader('Map To (Eduvia Field)', flex: 4),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),

                      // Table Rows
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _mappings.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          itemBuilder: (context, index) {
                            final mapping = _mappings[index];
                            final sampleValue = index < widget.sampleRow.length
                                ? widget.sampleRow[index]
                                : '—';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              color: mapping.eduviaFieldKey == 'skip'
                                  ? const Color(0xFFFAFAFA)
                                  : Colors.white,
                              child: Row(
                                children: [
                                  // Source Header
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.table_chart_rounded,
                                          size: 14,
                                          color: mapping.eduviaFieldKey == 'skip'
                                              ? AppTheme.textSecondary
                                              : AppTheme.primaryPurple,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            mapping.sourceHeader,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: mapping.eduviaFieldKey == 'skip'
                                                  ? AppTheme.textSecondary
                                                  : AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Sample Value
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      sampleValue,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // AI Confidence
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _confidenceIcon(mapping.confidence),
                                          size: 14,
                                          color: _confidenceColor(mapping.confidence),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _confidenceLabel(mapping.confidence),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _confidenceColor(mapping.confidence),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Dropdown
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: mapping.eduviaFieldKey == 'skip'
                                              ? const Color(0xFFE0E0E0)
                                              : AppTheme.primaryPurple.withValues(alpha: 0.3),
                                        ),
                                        color: mapping.eduviaFieldKey == 'skip'
                                            ? const Color(0xFFFAFAFA)
                                            : AppTheme.primaryPurple.withValues(alpha: 0.04),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: mapping.eduviaFieldKey,
                                          isExpanded: true,
                                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
                                          items: (widget.entityType == ImportEntityType.staff
                                                  ? EduviaField.staffFields
                                                  : EduviaField.studentFields)
                                              .map((field) {
                                            return DropdownMenuItem(
                                              value: field.key,
                                              child: Row(
                                                children: [
                                                  if (field.isRequired)
                                                    const Text('* ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                                  Flexible(
                                                    child: Text(
                                                      field.label,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: field.key == 'skip'
                                                            ? AppTheme.textSecondary
                                                            : AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                mapping.eduviaFieldKey = val;
                                                final idFieldKey = widget.entityType == ImportEntityType.staff ? 'staff_code' : 'admission_number';
                                                if (val == idFieldKey) {
                                                  _autoGenerateId = false;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
