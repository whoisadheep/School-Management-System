import 'dart:io';

Future<void> main(List<String> args) async {
  final currentDir = File(Platform.resolvedExecutable).parent.path;
  final logFile = File('$currentDir\\update_log.txt');
  
  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    logFile.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    print(message);
  }

  log('--- Update started ---');

  if (args.length < 2) {
    log('Usage: updater.exe <installerPath> <pid> [appName]');
    exit(1);
  }

  final installerPath = args[0];
  final pid = args[1];
  final appName = args.length > 2 ? args[2] : 'school_management_system.exe';
  final appPath = '$currentDir\\$appName';

  log('Waiting for main app (PID $pid) to exit...');
  
  for (int i = 0; i < 20; i++) {
    try {
      final result = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH']);
      if (!result.stdout.toString().contains(pid)) {
        break;
      }
    } catch (e) {
      // Ignore
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  await Future.delayed(const Duration(seconds: 1));

  log('Running installer silently: $installerPath');
  bool installSuccess = false;
  int? exitCode;

  // Retry loop: 5 attempts, 1 sec apart
  for (int attempt = 1; attempt <= 5; attempt++) {
    try {
      final result = await Process.run(installerPath, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART']);
      exitCode = result.exitCode;
      log('Installer finished with exit code: $exitCode (Attempt $attempt)');
      if (exitCode == 0) {
        installSuccess = true;
        break;
      } else {
        log('Installer returned non-zero exit code. Retrying...');
      }
    } catch (e) {
      log('Error launching installer (Attempt $attempt): $e');
    }
    
    if (attempt < 5) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  if (installSuccess) {
    if (await File(appPath).exists()) {
      log('Update successful. Relaunching new app: $appPath');
      await Process.start(appPath, [], mode: ProcessStartMode.detached);
    } else {
      log('Update successful but executable not found at $appPath');
    }
  } else {
    log('Update failed (Exit code: $exitCode). Relaunching old app: $appPath');
    if (await File(appPath).exists()) {
      await Process.start(appPath, [], mode: ProcessStartMode.detached);
    } else {
      log('Old executable not found at $appPath');
    }
  }
  
  log('--- Update finished ---');
}
