import 'dart:io';

void main() async {
  print('Starting cleanup of old assets...');
  
  final directoriesToRemove = [
    'assets/audio/capitulo 1',
    'assets/audio/capitulo 2',
    'assets/audio/Duo 1',
    'assets/audio/Instrumento',
  ];

  for (final dirPath in directoriesToRemove) {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
        print('Deleted: $dirPath');
      } catch (e) {
        print('Error deleting $dirPath: $e');
      }
    } else {
      print('Skipped (not found): $dirPath');
    }
  }

  print('Cleanup finished!');
}
