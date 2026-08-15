import 'dart:io';

import 'package:flutter/foundation.dart';

enum ConvertStatus { queued, converting, completed, error }

/// A single media conversion (format change or video → audio).
class ConvertTask extends ChangeNotifier {
  final String id;
  final String sourcePath;
  final String sourceName;
  final String outputPath;
  final String targetId;
  final double durationSeconds;
  String fileSize = '';
  ConvertStatus status = ConvertStatus.queued;
  double progress = 0.0;
  Process? process;
  final List<String> stderrTail = [];
  String mode = '';

  ConvertTask({
    required this.id,
    required this.sourcePath,
    required this.sourceName,
    required this.outputPath,
    required this.targetId,
    this.durationSeconds = 0,
  });

  String get targetLabel => targetId.toUpperCase();

  bool get isActive =>
      status == ConvertStatus.queued || status == ConvertStatus.converting;

  void update() => notifyListeners();
}