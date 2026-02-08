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
