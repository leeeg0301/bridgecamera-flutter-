import 'dart:convert';
import 'package:flutter/services.dart';

class BridgeService {
  Future<List<String>> loadBridgeNames() async {
    final raw = await rootBundle.loadString('assets/data.csv');

    final lines = const LineSplitter()
        .convert(raw)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final names = <String>{};

    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length >= 4) {
        final name = cols[3].trim();
        if (name.isNotEmpty) names.add(name);
      }
    }

    final result = names.toList()..sort();
    return result;
  }
}
