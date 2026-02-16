import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/saved_photo.dart';

class ManifestService {
  static const _manifest = 'saved_photos.json';

  Future<Directory> _baseDir() async => getApplicationDocumentsDirectory();

  Future<Directory> photosDir() async {
    final d = Directory(p.join((await _baseDir()).path, 'photos'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> zipsDir() async {
    final d = Directory(p.join((await _baseDir()).path, 'zips'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _manifestFile() async => File(p.join((await _baseDir()).path, _manifest));

  Future<List<SavedPhoto>> loadAll() async {
    final f = await _manifestFile();
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedPhoto.fromJson(e)).toList();
  }

  // ✅ 변경(2): manifest 저장을 atomic하게(깨짐 방지)
  // [설명] 앱이 저장 도중 꺼지면 JSON이 반쯤 써진 상태로 남아 "깨질" 수 있어.
  //        그래서 임시파일(.tmp)에 완성본을 먼저 쓰고 → 마지막에 rename으로 교체하면 안정적이야.
  Future<void> _saveAll(List<SavedPhoto> items) async {
    final f = await _manifestFile();
    final tmp = File('${f.path}.tmp');

    await tmp.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: true,
    );

    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  // ✅ 변경(1): 동일 파일명 덮어쓰기 방지용 함수
  // [설명] 이미 같은 파일명이 존재하면 뒤에 -001, -002...를 붙여서 새로운 이름을 만들어줌.
  Future<String> _avoidCollisionName(Directory dir, String name) async {
    final ext = p.extension(name);                 // 예: .jpg
    final base = p.basenameWithoutExtension(name); // 예: 영암1교-순천-A1-균열

    var candidate = name;
    var i = 1;

    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '${base}-${i.toString().padLeft(3, '0')}$ext';
      i++;
    }
    return candidate;
  }

  Future<SavedPhoto> savePhoto(File src, String name) async {
    final dir = await photosDir();

    // ✅ 변경(1): 안전한 파일명으로 바꾼 뒤 저장
    // [효과] 같은 이름으로 찍어도 기존 사진이 덮어써지지 않고,
    //        ...-001.jpg, ...-002.jpg로 계속 쌓임.
    final safeName = await _avoidCollisionName(dir, name);

    final dst = File(p.join(dir.path, safeName));
    await src.copy(dst.path);

    final now = DateTime.now().millisecondsSinceEpoch;

    final item = SavedPhoto(
      id: now.toString(),
      fileName: safeName, // ✅ safeName 저장
      filePath: dst.path,
      createdAtMs: now,
    );

    final list = await loadAll();
    list.insert(0, item);
    await _saveAll(list);
    return item;
  }

  Future<void> updateSelection(String id, bool v) async {
    final list = await loadAll();
    for (final e in list) {
      if (e.id == id) e.selected = v;
    }
    await _saveAll(list);
  }
}
