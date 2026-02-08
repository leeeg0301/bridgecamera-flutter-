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
