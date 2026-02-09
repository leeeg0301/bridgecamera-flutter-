import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/photo_item.dart';
import 'sanitizer.dart';

class ZipService {
  Future<String> buildZip({
    required List<PhotoItem> items,
    required bool makeFolders,
    required Directory outDir,
    String zipName = '점검사진_분류.zip',
  }) async {
    final selected = items.where((e) => e.selected).toList();
    final zipPath = p.join(outDir.path, zipName);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    for (final item in selected) {
      final f = File(item.path);
      if (!await f.exists()) continue;

      final fileName = p.basename(item.path);

      String arcName = fileName;
      if (makeFolders) {
        final parts = Sanitizer.splitBaseName(fileName);
        if (parts.length >= 3) {
          arcName = '${parts[0]}/${parts[1]}/${parts[2]}/$fileName';
        }
      }

      encoder.addFile(f, arcName);
    }

    encoder.close();
    return zipPath;
  }
}
