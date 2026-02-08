import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/saved_photo.dart';

class ManifestService {
  static const _manifest = 'saved_photos.json';

  Future<Directory> _baseDir() async =>
      getApplicationDocumentsDirectory();

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

  Future<File> _manifestFile() async =>
      File(p.join((await _baseDir()).path, _manifest));

  Future<List<SavedPhoto>> loadAll() async {
    final f = await _manifestFile();
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedPhoto.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<SavedPhoto> items) async {
    final f = await _manifestFile();
    await f.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<SavedPhoto> savePhoto(File src, String name) async {
    final dir = await photosDir();
    final dst = File(p.join(dir.path, name));
    await src.copy(dst.path);

    final item = SavedPhoto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: name,
      filePath: dst.path,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
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
