import 'dart:io';

void main() {
  final directory = Directory('c:/Users/DELL/Desktop/matrix/mang/mangalasutram_flutter/lib');
  
  final regex1 = RegExp(r"Text\('Error: \$e'\)");
  final regex2 = RegExp(r"Text\('Failed to upload: \$e'\)");
  final regex3 = RegExp(r"Text\('Failed to save: \$e'\)");
  final regex4 = RegExp(r"Text\('Load Error: \$e'\)");
  final regex5 = RegExp(r"Text\('Sign up failed: \$e'\)");
  final regex6 = RegExp(r"Text\('Google Sign-Up failed: \$e'\)");
  final regex7 = RegExp(r"Text\('Login failed: \$e'\)");
  final regex8 = RegExp(r"Text\('Google Sign-In failed: \$e'\)");
  final regex9 = RegExp(r"Text\(e\.toString\(\)\)");
  final regex10 = RegExp(r"Text\('Photo upload failed: \$\{e\.toString\(\)\}'\)");
  final regex11 = RegExp(r"Text\('Error: \$\{e\.toString\(\)\}'\)");

  final replacement = "Text(e is AppException ? e.message : 'Something went wrong. Please try again.')";

  int filesChanged = 0;

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool changed = false;

      final replacements = [regex1, regex2, regex3, regex4, regex5, regex6, regex7, regex8, regex9, regex10, regex11];
      for (final r in replacements) {
        if (r.hasMatch(content)) {
          content = content.replaceAll(r, replacement);
          changed = true;
        }
      }

      if (changed) {
        if (!content.contains('app_exception.dart')) {
          final importDepth = entity.path.split(Platform.pathSeparator).length - directory.path.split(Platform.pathSeparator).length;
          final prefix = '../' * importDepth;
          final importStmt = "import '${prefix}core/exceptions/app_exception.dart';\n";
          // Add import after the last import
          final lines = content.split('\n');
          int lastImport = -1;
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].startsWith('import ')) {
              lastImport = i;
            }
          }
          if (lastImport != -1) {
            lines.insert(lastImport + 1, importStmt);
            content = lines.join('\n');
          }
        }
        entity.writeAsStringSync(content);
        filesChanged++;
        print('Updated ${entity.path}');
      }
    }
  }

  print('Total files updated: $filesChanged');
}
