import 'package:flutter/services.dart';
import '../models/operation.dart';
import '../models/task.dart';

class PlaybackService {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _shizukuEnabled = false;
  bool get shizukuEnabled => _shizukuEnabled;

  final void Function(String)? onStatusChange;
  final void Function(int, int)? onProgress;

  PlaybackService({this.onStatusChange, this.onProgress});

  Future<bool> checkShizukuPermission() async {
    const channel = MethodChannel('com.clonex/shizuku');
    try {
      final result = await channel.invokeMethod<bool>('checkPermission');
      _shizukuEnabled = result ?? false;
      return _shizukuEnabled;
    } catch (e) {
      _shizukuEnabled = false;
      return false;
    }
  }

  Future<void> requestShizukuPermission() async {
    const channel = MethodChannel('com.clonex/shizuku');
    try {
      await channel.invokeMethod('requestPermission');
    } catch (e) {
      onStatusChange?.call('Shizuku 权限请求失败');
    }
  }

  Future<void> play(Task task) async {
    if (_isPlaying) return;
    _isPlaying = true;

    // 检查 Shizuku 权限
    await checkShizukuPermission();

    if (_shizukuEnabled) {
      onStatusChange?.call('使用 Shizuku 权限执行: ${task.name}');
    } else {
      onStatusChange?.call('使用无障碍服务执行: ${task.name}');
    }

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
    bool success = false;

    // 优先使用 Shizuku
    if (_shizukuEnabled) {
      success = await _executeWithShizuku(op);
    }

    // 如果 Shizuku 失败或不可用，回退到 AccessibilityService
    if (!success) {
      success = await _executeWithAccessibilityService(op);
    }
  }

  Future<bool> _executeWithShizuku(Operation op) async {
    const channel = MethodChannel('com.clonex/shizuku');

    try {
      bool? result;
      switch (op.type) {
        case OperationType.tap:
          result = await channel.invokeMethod<bool>('injectTap', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
          });
          break;
        case OperationType.longPress:
          result = await channel.invokeMethod<bool>('injectLongPress', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
            'duration': op.duration,
          });
          break;
        case OperationType.swipe:
          result = await channel.invokeMethod<bool>('injectSwipe', {
            'startX': op.x ?? 0,
            'startY': op.y ?? 0,
            'endX': op.endX ?? 0,
            'endY': op.endY ?? 0,
            'duration': 300,
          });
          break;
        case OperationType.scroll:
          result = await channel.invokeMethod<bool>('injectSwipe', {
            'startX': op.x ?? 540,
            'startY': op.y ?? 1500,
            'endX': op.x ?? 540,
            'endY': (op.y ?? 1500) + 300,
            'duration': 300,
          });
          break;
        case OperationType.back:
        case OperationType.home:
          // 这些通过无障碍服务执行
          return false;
        case OperationType.input:
          result = true;
          break;
      }
      if (result == true) {
        debugPrint('Shizuku executed: ${op.type.name}');
        return true;
      }
    } catch (e) {
      debugPrint('Shizuku failed: $e');
    }
    return false;
  }

  Future<bool> _executeWithAccessibilityService(Operation op) async {
    const platform = MethodChannel('com.clonex/automation');

    try {
      switch (op.type) {
        case OperationType.tap:
          await platform.invokeMethod('tap', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
          });
          break;
        case OperationType.longPress:
          await platform.invokeMethod('longPress', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
            'duration': op.duration,
          });
          break;
        case OperationType.swipe:
          await platform.invokeMethod('swipe', {
            'startX': op.x ?? 0,
            'startY': op.y ?? 0,
            'endX': op.endX ?? 0,
            'endY': op.endY ?? 0,
          });
          break;
        case OperationType.scroll:
          await platform.invokeMethod('scroll', {
            'x': op.x ?? 540,
            'y': op.y ?? 1500,
          });
          break;
        case OperationType.back:
          await platform.invokeMethod('back');
          break;
        case OperationType.home:
          await platform.invokeMethod('home');
          break;
        case OperationType.input:
          await platform.invokeMethod('input', {
            'text': op.text ?? '',
          });
          break;
      }
      debugPrint('AccessibilityService executed: ${op.type.name}');
      return true;
    } on PlatformException catch (e) {
      debugPrint('PlatformException: ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('MissingPluginException: Method channel not available');
      return false;
    }
  }

  void debugPrint(String msg) {
    // ignore: avoid_print
    print('[PlaybackService] $msg');
  }

  void stop() {
    _isPlaying = false;
    onStatusChange?.call('已停止');
  }
}
