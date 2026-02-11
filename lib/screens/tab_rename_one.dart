//1페이지 사진 촬영 및 파일명 규칙 적용 저장 화면
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../services/manifest_service.dart';
import '../services/sanitizer.dart';
import '../services/bridge_service.dart';

class TabRenameOne extends StatefulWidget { //상태가 변하기 때문에 Statefulwidget
  const TabRenameOne({super.key});

  @override
  State<TabRenameOne> createState() => _TabRenameOneState();
}

class _TabRenameOneState extends State<TabRenameOne> {
  final manifest = ManifestService();   //manifeservice 실제 파일저장 담당, json metadata관리
  final picker = ImagePicker();
  final bridgeService = BridgeService(); //bridgeService csv에서 교량 목록 불러옴

  // 교량에서 불러온 교량 목록
  List<String> bridges = [];

  String bridge = '';
  String direction = '순천';
  String location = 'A1';

  //사용자 선택값
  final descCtrl = TextEditingController();

  bool saving = false;
  String lastSaved = '-';  //저장 중 ui 비활성화용


  //initstate() -> _loadbridges()
  // 1.csv에서 교량 목록 로드
  // 2. bridges 리스트에 저장
  // 3  첫번째 교량을 기본값으로 설정
  @override
  void initState() {
    super.initState();
    _loadBridges();
  }

  Future<void> _loadBridges() async {
    final list = await bridgeService.loadBridgeNames();
    if (!mounted) return;

    setState(() {
      bridges = list;
      if (bridges.isNotEmpty) {
        bridge = bridges.first;
      }
    });
  }

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  //sanitizer.buildfilename() 특수문자 제거 공백처리, 파일명 규칙 통일
  // 교량-방향-위치-내용.jpg
  String _buildName(String ext) {
    return Sanitizer.buildFileName(
      bridge: bridge,
      direction: direction,
      location: location,
      desc: descCtrl.text,
      ext: ext,
    );
  }

  //사진 선택 및 저장 핵심 함수
  //1. 카메라실행 2. 이미지 선택 3. 확장자 추출 4. 파일명 생성 5.maifest.savphoto()
  //6. 성공시 스낵바 표시 7. 실패시 에러표시
  Future<void> _pickAndSave(ImageSource source) async {
    if (bridge.isEmpty) return;

    setState(() => saving = true);
    try {
      final x = await picker.pickImage(source: source, imageQuality: 100);
      if (x == null) return;

      final src = File(x.path);
      final ext = p.extension(x.path).replaceFirst('.', '').toLowerCase();
      final name = _buildName(ext.isEmpty ? 'jpg' : ext);

      await manifest.savePhoto(src, name);

      if (!mounted) return;
      setState(() => lastSaved = name);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 완료: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  //8. ui 구성
  // 1. 제목 2. 교량 dropdown 3. 방향 drop 4.위치 drop 5.내용 입력
  // 6.파일명 미리보기 7.촬영 버튼 8.갤러리 버튼 9.저장중 progressbar
  @override
  Widget build(BuildContext context) {
    final preview = bridge.isEmpty ? '-' : _buildName('jpg');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            '1페이지: 촬영/갤러리 → 파일명 적용 → 저장',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          /// 🔹 교량 (CSV 자동 연동)
          DropdownButtonFormField<String>(
            value: bridge.isEmpty ? null : bridge,
            items: bridges
                .map((b) => DropdownMenuItem(
              value: b,
              child: Text(b),
            ))
                .toList(),
            onChanged: saving
                ? null
                : (v) => setState(() => bridge = v ?? bridge),
            decoration: const InputDecoration(
              labelText: '교량',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          /// 🔹 방향
          DropdownButtonFormField<String>(
            value: direction,
            items: const [
              DropdownMenuItem(value: '순천', child: Text('순천')),
              DropdownMenuItem(value: '영암', child: Text('영암')),
            ],
            onChanged:
            saving ? null : (v) => setState(() => direction = v ?? direction),
            decoration: const InputDecoration(
              labelText: '방향',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          /// 🔹 위치
          DropdownButtonFormField<String>(
            value: location,
            items: const [
              DropdownMenuItem(value: 'A1', child: Text('A1')),
              DropdownMenuItem(value: 'A2', child: Text('A2')),
              DropdownMenuItem(value: 'P1', child: Text('P1')),
              DropdownMenuItem(value: 'S1', child: Text('S1')),
            ],
            onChanged:
            saving ? null : (v) => setState(() => location = v ?? location),
            decoration: const InputDecoration(
              labelText: '위치',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: descCtrl,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: '내용(선택)',
              hintText: '예: 균열, 박리, 누수',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),
          Text('파일명 미리보기: $preview'),
          const SizedBox(height: 6),
          Text('마지막 저장: $lastSaved'),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                  saving ? null : () => _pickAndSave(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                  saving ? null : () => _pickAndSave(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
            ],
          ),

          if (saving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('저장 중...'),
          ],
        ],
      ),
    );
  }
