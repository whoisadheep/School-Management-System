import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auto_update_provider.dart';

/// Slim, non-distracting 3px gradient progress bar that sits seamlessly
/// at the top of the content viewport while an update is downloading.
class AutoUpdateTopProgressBar extends ConsumerWidget {
  const AutoUpdateTopProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(autoUpdateProvider);

    if (updateState.status != AutoUpdateStatus.downloading) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: 3,
          color: AppTheme.primaryPurple.withValues(alpha: 0.12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: updateState.progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  widthFactor: value.clamp(0.01, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4C3BCF),
                          Color(0xFF7B68EE),
                          Color(0xFF9D7BFF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x664C3BCF),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Floating, non-intrusive modern glassmorphism auto-updater pill card
/// sitting in the corner of the application without blocking any user actions.
class AutoUpdateFloatingBanner extends ConsumerWidget {
  const AutoUpdateFloatingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(autoUpdateProvider);

    if (updateState.isDismissed ||
        updateState.status == AutoUpdateStatus.idle ||
        updateState.status == AutoUpdateStatus.checking) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 24,
      right: 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: updateState.isCollapsed
            ? _buildCollapsedPill(context, ref, updateState)
            : _buildExpandedCard(context, ref, updateState),
      ),
    );
  }

  Widget _buildCollapsedPill(
    BuildContext context,
    WidgetRef ref,
    AutoUpdateState updateState,
  ) {
    final version = updateState.updateInfo?.latestVersion ?? '';
    final percent = (updateState.progress * 100).toInt();
    final isReady = updateState.status == AutoUpdateStatus.readyToInstall;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(autoUpdateProvider.notifier).toggleCollapsed(),
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isReady
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : AppTheme.primaryPurple.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isReady ? const Color(0xFF10B981) : AppTheme.primaryPurple)
                        .withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReady) ...[
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'v$version Ready',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        value: updateState.progress > 0 ? updateState.progress : null,
                        strokeWidth: 2.2,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard(
    BuildContext context,
    WidgetRef ref,
    AutoUpdateState updateState,
  ) {
    final version = updateState.updateInfo?.latestVersion ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryPurple.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIconBadge(updateState.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _getTitle(updateState.status, version),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E1E2D),
                                ),
                              ),
                            ),
                            if (updateState.status == AutoUpdateStatus.downloading) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${(updateState.progress * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getSubtitle(updateState),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Collapse / Close actions
                  InkWell(
                    onTap: () => ref.read(autoUpdateProvider.notifier).toggleCollapsed(),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),

              // Progress Bar if downloading
              if (updateState.status == AutoUpdateStatus.downloading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: updateState.progress),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4C3BCF),
                                  Color(0xFF7B68EE),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Actions when Ready to Install
              if (updateState.status == AutoUpdateStatus.readyToInstall) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => ref.read(autoUpdateProvider.notifier).dismiss(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: Text(
                        'Later',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4C3BCF),
                            Color(0xFF3A2BA0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => ref.read(autoUpdateProvider.notifier).applyUpdateAndRestart(),
                        icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Colors.white),
                        label: Text(
                          'Restart & Install',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Error Retry Actions
              if (updateState.status == AutoUpdateStatus.error) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => ref.read(autoUpdateProvider.notifier).dismiss(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: Text(
                        'Dismiss',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(autoUpdateProvider.notifier).retry(),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: Text('Retry', style: GoogleFonts.poppins(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge(AutoUpdateStatus status) {
    if (status == AutoUpdateStatus.readyToInstall) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 20),
      );
    }

    if (status == AutoUpdateStatus.error) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.cloud_download_rounded,
        color: AppTheme.primaryPurple,
        size: 20,
      ),
    );
  }

  String _getTitle(AutoUpdateStatus status, String version) {
    switch (status) {
      case AutoUpdateStatus.downloading:
        return 'Downloading Update';
      case AutoUpdateStatus.readyToInstall:
        return 'Update v$version Ready';
      case AutoUpdateStatus.error:
        return 'Download Paused';
      default:
        return 'Eduvia Updater';
    }
  }

  String _getSubtitle(AutoUpdateState state) {
    switch (state.status) {
      case AutoUpdateStatus.downloading:
        final received = state.receivedMb.toStringAsFixed(1);
        final total = state.totalMb > 0 ? '${state.totalMb.toStringAsFixed(1)} MB' : '...';
        return '$received MB of $total';
      case AutoUpdateStatus.readyToInstall:
        return 'Restart anytime to complete update';
      case AutoUpdateStatus.error:
        return state.errorMessage != null && state.errorMessage!.length > 40
            ? '${state.errorMessage!.substring(0, 40)}...'
            : (state.errorMessage ?? 'Connection error');
      default:
        return '';
    }
  }
}
