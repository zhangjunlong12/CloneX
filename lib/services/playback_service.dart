import 'package:flutter/services.dart';
import '../models/operation.dart';
import '../models/task.dart';

class PlaybackService {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  final void Function(String)? onStatusChange;
  final void Function(int, int)? onProgress;

  PlaybackService({this.onStatusChange, this.onProgress});

  Future<void> play(Task task) async {
    if (_isPlaying) return;
    _isPlaying = true;
    onStatusChange?.call('正在重放: ${task.name}');

    try {
      final operations = task.operations;
      for (int i = 0; i < operations.length; i++) {
        if (!_isPlaying) break;

        final op = operations[i];
        await _executeOperation(op);

        onProgress?.call(i + 1, operations.length);

        if (i < operations.length - 1) {
          final nextOp = operations[i + 1];
          final delay = nextOp.timestamp.difference(op.timestamp);
          if (delay.inMilliseconds > 0 && delay.inMilliseconds < 5000) {
            await Future.delayed(delay);
          }
        }
      }

      onStatusChange?.call('重放完成');
    } catch (e) {
      onStatusChange?.call('重放失败: $e');
    } finally {
      _isPlaying = false;
    }
  }

  Future<void> _executeOperation(Operation op) async {
    const platform = MethodChannel('com.clonex/automation');

    try {
      switch (op.type) {
        case OperationType.tap:
          await platform.invokeMethod('tap', {
            'x': op.x,
            'y': op.y,
          });
          break;
        case OperationType.longPress:
          await platform.invokeMethod('longPress', {
            'x': op.x,
            'y': op.y,
            'duration': op.duration,
          });
          break;
        case OperationType.swipe:
          await platform.invokeMethod('swipe', {
            'startX': op.x,
            'startY': op.y,
            'endX': op.endX,
            'endY': op.endY,
          });
          break;
        case OperationType.input:
          await platform.invokeMethod('input', {
            'text': op.text,
          });
          break;
        case OperationType.scroll:
          await platform.invokeMethod('scroll', {
            'x': op.x,
            'y': op.y,
          });
          break;
        case OperationType.back:
          await platform.invokeMethod('back');
          break;
        case OperationType.home:
          await platform.invokeMethod('home');
          break;
      }
    } on MissingPluginException {
      // Android 端插件未实现时静默处理
    }
  }

  void stop() {
    _isPlaying = false;
    onStatusChange?.call('已停止');
  }
}
