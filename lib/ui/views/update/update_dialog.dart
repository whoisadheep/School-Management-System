import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/core/theme/app_theme.dart';
import 'package:school_management_system/services/app_logger.dart';
import 'package:school_management_system/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusMessage = '';

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Starting download...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final installerPath = '${tempDir.path}\\sms_updater_${widget.updateInfo.latestVersion}.exe';
      
      final dio = Dio();
      
      // Get content length first
      final headResponse = await dio.head(widget.updateInfo.downloadUrl);
      final expectedSize = int.parse(headResponse.headers.value(HttpHeaders.contentLengthHeader) ?? '-1');

      await dio.download(
        widget.updateInfo.downloadUrl,
        installerPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _statusMessage = 'Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      // Verify file size
      final downloadedFile = File(installerPath);
      if (expectedSize != -1) {
        final actualSize = await downloadedFile.length();
        if (actualSize != expectedSize) {
          throw Exception('Download incomplete. Expected $expectedSize bytes but got $actualSize bytes.');
        }
      }

      // Verify SHA256
      if (widget.updateInfo.sha256.isNotEmpty) {
        setState(() {
          _statusMessage = 'Verifying file integrity...';
        });
        final bytes = await downloadedFile.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        if (hash.toLowerCase() != widget.updateInfo.sha256.toLowerCase()) {
          throw Exception('Security error: File hash mismatch (expected ${widget.updateInfo.sha256}, got $hash).');
        }
      }

      setState(() {
        _statusMessage = 'Download complete. Launching updater...';
      });

      // Launch updater and exit
      await _launchUpdater(installerPath);

    } catch (e, stack) {
      AppLogger.instance.error('Update download failed', e, stack);
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Update failed: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _launchUpdater(String installerPath) async {
    try {
      final file = File(installerPath);
      
      if (!await file.exists()) {
        throw Exception('Installer not found at $installerPath');
      }
      
      // Launch installer process asynchronously and detach
      // /SILENT and /SP- are Inno Setup arguments for background install
      await Process.start(
        installerPath,
        [],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      
      // Exit the current app so installer can overwrite files
      exit(0);
    } catch (e, stack) {
      AppLogger.instance.error('Failed to launch updater', e, stack);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Failed to launch updater: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.updateInfo.isMandatory && !_isDownloading,
      child: Dialog(
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: AppTheme.primaryPurple, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Update Available',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  if (!widget.updateInfo.isMandatory && !_isDownloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Version ${widget.updateInfo.latestVersion} is now available.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.bgMain,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Text(
                  widget.updateInfo.changelog.isEmpty ? 'Bug fixes and performance improvements.' : widget.updateInfo.changelog,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 24),
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.primarySoft,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.updateInfo.isMandatory)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Remind Me Later', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Update Now'),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
