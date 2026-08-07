import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';
import '../../../services/backup_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/app_logger.dart';

final backupsListProvider = FutureProvider<List<BackupFileInfo>>((ref) async {
  final backupService = BackupService();
  return await backupService.listAvailableBackups();
});

// ── Settings Tab Enum ──
enum _SettingsTab { schoolProfile, exportPaths, database, modules, about }

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView>
    with TickerProviderStateMixin {
  // Controllers
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolContactController = TextEditingController();
  final _schoolMottoController = TextEditingController();
  final _schoolPrincipalController = TextEditingController();
  final _receiptPathController = TextEditingController();
  final _backupPathController = TextEditingController();

  final SettingsService _settingsService = SettingsService();
  final BackupService _backupService = BackupService();

  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isSaving = false;
  bool _isRecalculating = false;
  _SettingsTab _activeTab = _SettingsTab.schoolProfile;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final receiptPath = await _settingsService.getReceiptExportPath();
    final backupPath =
        await _settingsService.getSetting('backup_export_path') ?? '';
    final schoolName = await _settingsService.getSetting('school_name') ??
        'EXCELLENCE ACADEMY SCHOOL';
    final schoolAddress =
        await _settingsService.getSetting('school_address') ??
            '123 Education Boulevard, Academic District';
    final schoolContact =
        await _settingsService.getSetting('school_contact') ??
            'Phone: +1 800 555-0199 | Email: finance@school.edu';
    final schoolMotto =
        await _settingsService.getSetting('school_motto') ??
            'Inspiring Excellence, Building Futures';
    final schoolPrincipal =
        await _settingsService.getSetting('school_principal') ?? '';

    if (mounted) {
      setState(() {
        _receiptPathController.text = receiptPath;
        _backupPathController.text = backupPath;
        _schoolNameController.text = schoolName;
        _schoolAddressController.text = schoolAddress;
        _schoolContactController.text = schoolContact;
        _schoolMottoController.text = schoolMotto;
        _schoolPrincipalController.text = schoolPrincipal;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _receiptPathController.dispose();
    _backupPathController.dispose();
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolContactController.dispose();
    _schoolMottoController.dispose();
    _schoolPrincipalController.dispose();
    super.dispose();
  }

  void _switchTab(_SettingsTab tab) {
    if (tab == _activeTab) return;
    _fadeController.reset();
    setState(() => _activeTab = tab);
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppTheme.bgMain,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading System Settings…',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: Row(
        children: [
          // ── Left Sidebar Navigation ──
          _buildSidebar(),
          // ── Main Content Area ──
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(36),
                child: _buildActiveTabContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SIDEBAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: AppTheme.primarySoft.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple,
                  AppTheme.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'System Configuration',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Nav Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  icon: Icons.school_rounded,
                  label: 'School Profile',
                  subtitle: 'Branding & Identity',
                  tab: _SettingsTab.schoolProfile,
                ),
                _buildNavItem(
                  icon: Icons.folder_open_rounded,
                  label: 'Export Paths',
                  subtitle: 'File & Receipt Directories',
                  tab: _SettingsTab.exportPaths,
                ),
                _buildNavItem(
                  icon: Icons.storage_rounded,
                  label: 'Database & Recovery',
                  subtitle: 'Backups & Maintenance',
                  tab: _SettingsTab.database,
                ),
                _buildNavItem(
                  icon: Icons.extension_rounded,
                  label: 'System Modules',
                  subtitle: 'Enable/Disable Features',
                  tab: _SettingsTab.modules,
                ),
                _buildNavItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  subtitle: 'System Information',
                  tab: _SettingsTab.about,
                ),
              ],
            ),
          ),

          // Single PC Note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Note: This app runs on a single computer and does not sync data across multiple PCs. All users must use this installed copy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),

          // Version badge at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgMain,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded,
                      size: 16, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Text(
                    'v1.0.0 — Licensed',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required _SettingsTab tab,
  }) {
    final isActive = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _switchTab(tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryPurple.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.15))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                        : AppTheme.bgMain,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? AppTheme.primaryPurple
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primaryPurple
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIVE TAB CONTENT ROUTER
  // ══════════════════════════════════════════════════════════════
  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case _SettingsTab.schoolProfile:
        return _buildSchoolProfileTab();
      case _SettingsTab.exportPaths:
        return _buildExportPathsTab();
      case _SettingsTab.database:
        return _buildDatabaseTab();
      case _SettingsTab.modules:
        return _buildModulesTab();
      case _SettingsTab.about:
        return _buildAboutTab();
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 1 — SCHOOL PROFILE
  // ══════════════════════════════════════════════════════════════
  Widget _buildSchoolProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          icon: Icons.school_rounded,
          title: 'School Profile & Branding',
          subtitle:
              'Configure the official school identity printed on receipts, ID cards, and exports.',
        ),
        const SizedBox(height: 28),

        // Live Preview Card
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('RECEIPT HEADER PREVIEW'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.bgMain,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primarySoft.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryLight
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _schoolNameController.text.isNotEmpty
                          ? _schoolNameController.text.toUpperCase()
                          : 'YOUR SCHOOL NAME',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_schoolMottoController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${_schoolMottoController.text}"',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.primaryPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _schoolAddressController.text.isNotEmpty
                          ? _schoolAddressController.text
                          : 'School Address Line',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _schoolContactController.text.isNotEmpty
                          ? _schoolContactController.text
                          : 'Contact Details',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // School Profile Fields
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('SCHOOL IDENTITY'),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _schoolNameController,
                label: 'Official School Name',
                hint: 'e.g. EXCELLENCE ACADEMY SCHOOL',
                icon: Icons.business_rounded,
                helper:
                    'Printed at the top of all A4 fee receipts and ID cards.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _schoolMottoController,
                label: 'School Motto / Tagline',
                hint: 'e.g. Inspiring Excellence, Building Futures',
                icon: Icons.format_quote_rounded,
                helper: 'Displayed in italics below the school name.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _schoolPrincipalController,
                label: 'Principal / Director Name',
                hint: 'e.g. Dr. Rajesh Kumar',
                icon: Icons.person_rounded,
                helper:
                    'Used as the signatory authority on official documents.',
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _schoolAddressController,
                label: 'School Address',
                hint: 'e.g. 123 Education Boulevard, Academic District',
                icon: Icons.location_on_rounded,
                helper: 'Printed under the school name on receipt headers.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _schoolContactController,
                label: 'Contact Phone & Email',
                hint:
                    'e.g. Phone: +91 98765-43210 | Email: office@school.edu',
                icon: Icons.phone_rounded,
                helper: 'Official contact details printed on receipts.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 28),
              _buildSaveButton(
                label: 'SAVE SCHOOL PROFILE',
                icon: Icons.save_rounded,
                onPressed: _saveAllSettings,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 2 — EXPORT PATHS
  // ══════════════════════════════════════════════════════════════
  Widget _buildExportPathsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          icon: Icons.folder_open_rounded,
          title: 'Export & Output Directories',
          subtitle:
              'Configure where receipts, reports, and backups are saved on the local filesystem.',
        ),
        const SizedBox(height: 28),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('PDF RECEIPT OUTPUT'),
              const SizedBox(height: 8),
              Text(
                'Fee receipts generated via the Fee Collection module will be saved as A4 PDF files at this location.',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _receiptPathController,
                label: 'A4 PDF Receipt Save Path',
                hint: 'e.g. /home/user/SMS_Receipts',
                icon: Icons.picture_as_pdf_rounded,
              ),
              const SizedBox(height: 8),
              _buildPathStatusChip(_receiptPathController.text),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('DATABASE BACKUP DIRECTORY'),
              const SizedBox(height: 8),
              Text(
                'SQLite .db backup snapshots will be stored in this directory. Recommended: use an external drive or cloud-synced folder.',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _buildSettingsField(
                controller: _backupPathController,
                label: 'Automated Secondary Backup Directory',
                hint: 'e.g. /home/user/SchoolBackups',
                icon: Icons.cloud_upload_rounded,
              ),
              const SizedBox(height: 8),
              _buildPathStatusChip(_backupPathController.text),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildCard(
          child: _buildSaveButton(
            label: 'SAVE DIRECTORY SETTINGS',
            icon: Icons.save_rounded,
            onPressed: _saveAllSettings,
            isLoading: _isSaving,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 3 — DATABASE & RECOVERY
  // ══════════════════════════════════════════════════════════════
  Widget _buildDatabaseTab() {
    final backupsAsync = ref.watch(backupsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          icon: Icons.storage_rounded,
          title: 'Database & Disaster Recovery',
          subtitle:
              'Create backup snapshots, restore from previous backups, and run maintenance operations.\nNote: To migrate this software to a new office PC, create a backup here, manually move the single .db file to the new PC, and restore it.',
        ),
        const SizedBox(height: 28),

        // Action Buttons
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('BACKUP & MAINTENANCE ACTIONS'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.backup_rounded,
                      title: 'Create Backup',
                      subtitle: 'Instant database snapshot',
                      color: AppTheme.primaryPurple,
                      isLoading: _isBackingUp,
                      onTap: _isBackingUp ? null : _triggerDailyAutoBackup,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.build_circle_rounded,
                      title: 'Repair Balances',
                      subtitle: 'Recompute student ledgers',
                      color: AppTheme.warning,
                      isLoading: _isRecalculating,
                      onTap:
                          _isRecalculating ? null : _recalculateStudentBalances,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.restart_alt_rounded,
                      title: 'Restore Backup',
                      subtitle: 'Load from a .db file',
                      color: AppTheme.error,
                      onTap: _showRestoreDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Backup History
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('BACKUP HISTORY'),
                  IconButton(
                    onPressed: () => ref.invalidate(backupsListProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: AppTheme.textSecondary,
                    tooltip: 'Refresh backup list',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              backupsAsync.when(
                data: (backups) {
                  if (backups.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 48,
                              color:
                                  AppTheme.textHint.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No database backups generated yet',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "Create Backup" above to generate your first snapshot.',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: backups.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppTheme.primarySoft.withValues(alpha: 0.4),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final b = backups[index];
                      final sizeKb = (b.sizeBytes / 1024).toStringAsFixed(1);
                      final dateStr = DateFormat('MMM dd, yyyy — hh:mm a')
                          .format(b.modifiedDate);
                      final isLatest = index == 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isLatest
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.bgMain,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isLatest
                                ? Icons.verified_rounded
                                : Icons.description_outlined,
                            color: isLatest
                                ? AppTheme.success
                                : AppTheme.textHint,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.fileName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLatest)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'LATEST',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '$dateStr  •  $sizeKb KB',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.content_copy_rounded,
                              size: 16),
                          color: AppTheme.textSecondary,
                          tooltip: 'Copy file path',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b.path));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Path copied to clipboard',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white),
                                ),
                                backgroundColor: AppTheme.primaryPurple,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple, strokeWidth: 2),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $err',
                      style: GoogleFonts.poppins(color: AppTheme.error)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 4 — ABOUT
  // ══════════════════════════════════════════════════════════════
  Widget _buildAboutTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          icon: Icons.info_outline_rounded,
          title: 'About This System',
          subtitle:
              'System information, version details, and keyboard shortcuts.',
        ),
        const SizedBox(height: 28),

        _buildCard(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'School Management System',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0  •  Desktop Edition',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '● System Operational',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                  color: AppTheme.primarySoft.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              Text(
                'Built with Flutter & SQLite for offline-first school administration.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('KEYBOARD SHORTCUTS'),
              const SizedBox(height: 16),
              _buildShortcutRow('Ctrl + 1', 'Dashboard'),
              _buildShortcutRow('Ctrl + 2', 'Fee Collection'),
              _buildShortcutRow('Ctrl + 3', 'Admissions (Students)'),
              _buildShortcutRow('Ctrl + 4', 'Student Directory'),
              _buildShortcutRow('Ctrl + 5', 'Staff Directory'),
              _buildShortcutRow('Ctrl + 6', 'Operational Expenses'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('TECHNOLOGY STACK'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildTechChip('Flutter', Icons.flutter_dash_rounded),
                  _buildTechChip('Dart', Icons.code_rounded),
                  _buildTechChip('SQLite (FFI)', Icons.storage_rounded),
                  _buildTechChip('Riverpod', Icons.layers_rounded),
                  _buildTechChip('fl_chart', Icons.bar_chart_rounded),
                  _buildTechChip('PDF / Printing', Icons.print_rounded),
                  _buildTechChip('Google Fonts', Icons.font_download_rounded),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  REUSABLE UI COMPONENTS
  // ══════════════════════════════════════════════════════════════

  Widget _buildTabHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple,
            AppTheme.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            color: AppTheme.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            color: AppTheme.textHint.withValues(alpha: 0.5), fontSize: 13),
        helperText: helper,
        helperStyle:
            GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 11),
        prefixIcon: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        filled: true,
        fillColor: AppTheme.bgMain.withValues(alpha: 0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: AppTheme.primarySoft.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSaveButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppTheme.primaryPurple,
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildPathStatusChip(String path) {
    final bool hasPath = path.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasPath
            ? AppTheme.success.withValues(alpha: 0.08)
            : AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPath
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: hasPath ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: 6),
          Text(
            hasPath ? 'Path configured' : 'No custom path configured — using default',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasPath ? AppTheme.success : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow(String shortcut, String action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.bgMain,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.primarySoft.withValues(alpha: 0.6)),
            ),
            child: Text(
              shortcut,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            action,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.primarySoft.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryPurple),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    try {
      await _settingsService.setReceiptExportPath(_receiptPathController.text);
      await _settingsService.setSetting(
          'backup_export_path', _backupPathController.text);
      await _settingsService.setSetting(
          'school_name', _schoolNameController.text);
      await _settingsService.setSetting(
          'school_address', _schoolAddressController.text);
      await _settingsService.setSetting(
          'school_contact', _schoolContactController.text);
      await _settingsService.setSetting(
          'school_motto', _schoolMottoController.text);
      await _settingsService.setSetting(
          'school_principal', _schoolPrincipalController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All settings saved successfully!',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to create manual backup', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _triggerDailyAutoBackup() async {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.databaseBackupRestore)) return;
    setState(() => _isBackingUp = true);
    try {
      final backupFile = await _backupService.createDailyAutoBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup created: ${backupFile.path.split('/').last}',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      ref.invalidate(backupsListProvider);
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to restore database backup', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _recalculateStudentBalances() async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warning, size: 24),
            const SizedBox(width: 10),
            Text('Confirm Balance Repair',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will recompute current_balance for every student from their invoice and transaction records. '
          'This operation is safe but may take a moment for large databases.\n\nProceed?',
          style: GoogleFonts.poppins(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
            ),
            child: Text('Repair Balances',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRecalculating = true);
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.recalculateAllStudentBalances();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All student balances recomputed and verified!',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      ref.invalidate(studentsListProvider);
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to seed sample data', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  void _showRestoreDialog() {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.databaseBackupRestore)) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded,
                color: AppTheme.error, size: 24),
            const SizedBox(width: 10),
            Text('Restore Database',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dangerous_rounded,
                      color: AppTheme.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DESTRUCTIVE ACTION — This will overwrite the current database with the selected backup. All data entered since the backup was created will be lost.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To restore, select a .db backup file from your Backups folder using your system file manager, then use the backup service API.',
              style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TAB 5 — SYSTEM MODULES
  // ══════════════════════════════════════════════════════════════
  Widget _buildModulesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          icon: Icons.extension_rounded,
          title: 'System Modules',
          subtitle: 'Enable or disable optional modules for your school.',
        ),
        const SizedBox(height: 28),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('AVAILABLE MODULES'),
              const SizedBox(height: 16),
              
              Consumer(
                builder: (context, ref, _) {
                  final hostelFlagAsync = ref.watch(featureFlagProvider('hostel_management'));
                  
                  return hostelFlagAsync.when(
                    data: (isEnabled) {
                      return _buildModuleToggle(
                        icon: Icons.apartment_rounded,
                        title: 'Hostel Management',
                        description: 'Manage hostel buildings, rooms, student allocations, and wardens.',
                        isEnabled: isEnabled,
                        onChanged: (val) async {
                          if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.toggleFeatureFlag)) return;
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.toggleFeature('hostel_management', val);
                          ref.invalidate(featureFlagProvider('hostel_management'));
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading flag: $e'),
                  );
                }
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleToggle({
    required IconData icon,
    required String title,
    required String description,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEnabled ? AppTheme.primaryLight.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isEnabled ? AppTheme.primaryPurple : Colors.grey, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: AppTheme.primaryPurple,
          ),
        ],
      ),
    );
  }
}
