1. lib/pubspec.yaml

dependencies:
  flutter:
    sdk: flutter

  csv: ^6.0.0
  file_picker: ^8.0.0
  archive: ^3.6.1
  path_provider: ^2.1.4
  path: ^1.9.0
  share_plus: ^10.0.0
  image_picker: ^1.0.8
  cupertino_icons: ^1.0.8

flutter:
  uses-material-design: true
  assets:
    - assets/

2. lib/main.dart
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const BridgeCameraApp());
}

class BridgeCameraApp extends StatelessWidget {
  const BridgeCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '점검도우미',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

3.lib/services/manifest_service.dart
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


4.lib/services/sanitizer.dart
class Sanitizer {
  static const String delim = '-';

  static String safeText(String? s) {
    if (s == null) return '';
    var t = s.trim();

    const banned = ['<', '>', ':', '"', '/', '\\', '|', '?', '*'];
    for (final ch in banned) {
      t = t.replaceAll(ch, '');
    }

    t = t.replaceAll('-', '_').replaceAll('.', '_');
    t = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
    return t;
  }

  static String buildFileName({
    required String bridge,
    required String direction,
    required String location,
    String? desc,
    String ext = 'jpg',
  }) {
    final parts = <String>[
      safeText(bridge),
      safeText(direction),
      safeText(location),
    ];

    final d = safeText(desc);
    if (d.isNotEmpty) parts.add(d);

    return '${parts.join(delim)}.$ext';
  }

  static List<String> splitBaseName(String fileName) {
    final base = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return base.split(delim);
  }
}

5. lib/screens/home_tabs.dart
import 'package:flutter/material.dart';
import 'tab_rename_one.dart';
import 'tab_zip_multi.dart';

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('점검도우미'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '1페이지: 저장'),
              Tab(text: '2페이지: ZIP'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TabRenameOne(),
            TabZipMulti(),
          ],
        ),
      ),
    );
  }
}

6.lib/screens/tab_capture.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_photo.dart';
import '../services/manifest_service.dart';

class TabCapture extends StatefulWidget {
  const TabCapture({super.key});

  @override
  State<TabCapture> createState() => _TabCaptureState();
}

class _TabCaptureState extends State<TabCapture> {
  final manifest = ManifestService();

  Future<void> _mockSave() async {
    final dir = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final file = File('${dir.path}/$id.jpg');

    await file.writeAsString('dummy');

    final photo = SavedPhoto(
      id: id,
      filePath: file.path,
      fileName: 'IMG_$id.jpg',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      selected: true,
    );

    await manifest.add(photo);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 저장 완료 (샘플)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _mockSave,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('사진 저장 (샘플)'),
      ),
    );
  }
}

7. lib/screens/tab_zip_multi.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models/photo_item.dart';
import '../models/saved_photo.dart';
import '../services/manifest_service.dart';
import '../services/zip_service.dart';

class TabZipMulti extends StatefulWidget {
  const TabZipMulti({super.key});

  @override
  State<TabZipMulti> createState() => _TabZipMultiState();
}

class _TabZipMultiState extends State<TabZipMulti> {
  final manifest = ManifestService();
  final zipService = ZipService();

  List<SavedPhoto> items = [];
  bool makeFolders = true;
  bool working = false;

  String? lastZipPath;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await manifest.loadAll();
    if (mounted) setState(() => items = list);
  }

  Future<void> _toggle(String id, bool v) async {
    await manifest.updateSelection(id, v);
    await _reload();
  }

  Future<void> _buildZip() async {
    final selected = items.where((e) => e.selected).toList();
    if (selected.isEmpty) return;

    setState(() => working = true);

    try {
      final outDir = await manifest.zipsDir();

      final photoItems = selected
          .map((e) => PhotoItem(
                path: e.filePath,
                name: e.fileName,
                selected: true,
              ))
          .toList();

      final zipPath = await zipService.buildZip(
        items: photoItems,
        makeFolders: makeFolders,
        outDir: outDir,
      );

      if (mounted) {
        setState(() => lastZipPath = zipPath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ZIP 생성 완료: ${p.basename(zipPath)}')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = items.where((e) => e.selected).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CheckboxListTile(
            value: makeFolders,
            onChanged: (v) => setState(() => makeFolders = v ?? true),
            title: const Text('폴더 분류'),
          ),
          Row(
            children: [
              Text('총 ${items.length} / 선택 $selectedCount'),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    (working || selectedCount == 0) ? null : _buildZip,
                child: const Text('ZIP 생성'),
              ),
            ],
          ),
          if (lastZipPath != null)
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await Share.shareXFiles([XFile(lastZipPath!)]);
                  },
                  child: const Text('공유'),
                ),
              ],
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return CheckboxListTile(
                  value: it.selected,
                  onChanged: (v) => _toggle(it.id, v ?? false),
                  title: Text(it.fileName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

8. lib/models/photo_item.dart

class PhotoItem {
  final String path;
  final String name;
  bool selected;

  PhotoItem({
    required this.path,
    required this.name,
    this.selected = true,
  });
}

9. lib/models/saved_photo.dart
class SavedPhoto {
  final String id;
  final String fileName;
  final String filePath;
  final int createdAtMs;
  bool selected;

  SavedPhoto({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAtMs,
    this.selected = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'filePath': filePath,
        'createdAtMs': createdAtMs,
        'selected': selected,
      };

  static SavedPhoto fromJson(Map<String, dynamic> j) => SavedPhoto(
        id: j['id'],
        fileName: j['fileName'],
        filePath: j['filePath'],
        createdAtMs: j['createdAtMs'],
        selected: j['selected'],
      );
}
