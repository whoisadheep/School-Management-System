import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static const String _mediaFolder = 'Eduvia/Media';

  /// Copies a file to the application's dedicated media directory
  /// and returns the absolute path of the newly copied file.
  static Future<String> copyFileToAppDirectory(String sourcePath) async {
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist');
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String targetDirPath = p.join(appDocDir.path, _mediaFolder);
    final Directory targetDir = Directory(targetDirPath);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final String extension = p.extension(sourcePath);
    final String newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
    final String targetFilePath = p.join(targetDirPath, newFileName);

    final File copiedFile = await sourceFile.copy(targetFilePath);
    return copiedFile.path;
  }
}
