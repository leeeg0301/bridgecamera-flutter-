import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/photo_item.dart';
import 'sanitizer.dart';

class ZipService {
  // ✅ 변경(3): ZIP 파일명 덮어쓰기 방지
  // [설명]
  // - zipName이 지정되지 않으면: "점검사진_YYYYMMDD_HHMMSS.zip" 자동 생성
  // - 같은 이름이 이미 있으면: "...-001.zip" 처럼 번호 자동 증가
  Future<String> buildZip({
    required List<PhotoItem> items,
    required bool makeFolders,
    required Directory outDir,
    String? zipName, // ✅ 변경: 기본값 고정 문자열 제거(덮어쓰기 방지)
  }) async {
    final selected = items.where((e) => e.selected).toList();
    if (selected.isEmpty) {
      // 기존 코드는 그냥 진행했는데, 선택이 0이면 zip이 의미가 없으니 방어적으로 처리
      throw Exception('선택된 사진이 없습니다.');
    }

    // 1) zipName이 없으면 timestamp 기반 기본 이름 생성
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final baseZipName = zipName ?? '점검사진_$stamp.zip';

    // 2) outDir 안에서 zipName 중복되면 -001 붙이기
    final finalZipName = await _avoidZipCollision(outDir, baseZipName);
    final zipPath = p.join(outDir.path, finalZipName);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    for (final item in selected) {
      final f = File(item.path);
      if (!await f.exists()) continue;

      // ※ 주의: ZIP 내부 파일명은 "실제 파일명"을 써야 폴더분류가 Sanitizer.splitBaseName과 맞아.
      // 네 원본은 p.basename(item.path)로 되어 있어 OK.
      final fileName = p.basename(item.path);

      String arcName = fileName;
      if (makeFolders) {
        final parts = Sanitizer.splitBaseName(fileName);

        // 교량/방향/위치까지만 폴더 분류 (내용은 폴더 분류 X)
        if (parts.length >= 3) {
          arcName = '${parts[0]}/${parts[1]}/${parts[2]}/$fileName';
        }
      }

      encoder.addFile(f, arcName);
    }

    encoder.close();
    return zipPath;
  }

  // ✅ 변경(3): ZIP 이름 충돌 방지 함수
  Future<String> _avoidZipCollision(Directory dir, String name) async {
    final ext = p.extension(name);                 // .zip
    final base = p.basenameWithoutExtension(name); // 점검사진_20260216_...
    var candidate = name;
    var i = 1;

    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '${base}-${i.toString().padLeft(3, '0')}$ext';
      i++;
    }
    return candidate;
  }
}
