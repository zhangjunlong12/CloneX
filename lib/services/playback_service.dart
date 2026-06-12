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

    // 优先使用元素级无障碍服务，让任务能适应控件位置变化。
    if (op.elementText != null ||
        op.elementId != null ||
        op.elementDescription != null ||
        op.type == OperationType.scroll ||
        op.type == OperationType.input) {
      success = await _executeWithElementService(op);
    }

    // Shell/root 能力只作为增强路径，不作为普通用户重放的前置条件。
    if (!success && _shizukuEnabled) {
      success = await _executeWithShizuku(op);
    }

    // 最后回退到无障碍坐标手势和全局动作。
    if (!success) {
      success = await _executeWithAccessibilityService(op);
    }

    if (!success) {
      throw Exception('执行失败: ${op.typeDescription}');
    }
  }

  Future<bool> _executeWithElementService(Operation op) async {
    const channel = MethodChannel('com.clonex/element');

    try {
      bool? result;

      // 优先使用 elementText
      if (op.elementText != null && op.elementText!.isNotEmpty) {
        result = await channel.invokeMethod<bool>('findAndClickByText', {
          'text': op.elementText,
        });
        if (result == true) {
          debugPrint('ElementService clicked by text: ${op.elementText}');
          return true;
        }
      }

      // 尝试 elementId
      if (op.elementId != null && op.elementId!.isNotEmpty) {
        result = await channel.invokeMethod<bool>('findAndClickByViewId', {
          'viewId': op.elementId,
        });
        if (result == true) {
          debugPrint('ElementService clicked by viewId: ${op.elementId}');
          return true;
        }
      }

      // 尝试 elementDescription
      if (op.elementDescription != null && op.elementDescription!.isNotEmpty) {
        result = await channel.invokeMethod<bool>('findAndClickByDescription', {
          'description': op.elementDescription,
        });
        if (result == true) {
          debugPrint('ElementService clicked by description: ${op.elementDescription}');
          return true;
        }
      }

      // 如果是 scroll 操作
      if (op.type == OperationType.scroll) {
        result = await channel.invokeMethod<bool>('findAndScroll');
        if (result == true) {
          debugPrint('ElementService scrolled');
          return true;
        }
      }

      if (op.type == OperationType.input && op.text != null) {
        result = await channel.invokeMethod<bool>('setFocusedText', {
          'text': op.text,
        });
        if (result == true) {
          debugPrint('ElementService set focused text');
          return true;
        }
      }
    } catch (e) {
      debugPrint('ElementService failed: $e');
    }
    return false;
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
          result = await channel.invokeMethod<bool>('injectKeyEvent', {
            'keyCode': 4,
          });
          break;
        case OperationType.home:
          result = await channel.invokeMethod<bool>('injectKeyEvent', {
            'keyCode': 3,
          });
          break;
        case OperationType.input:
          result = await channel.invokeMethod<bool>('injectText', {
            'text': op.text ?? '',
          });
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
      bool? result;
      switch (op.type) {
        case OperationType.tap:
          result = await platform.invokeMethod<bool>('tap', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
          });
          break;
        case OperationType.longPress:
          result = await platform.invokeMethod<bool>('longPress', {
            'x': op.x ?? 0,
            'y': op.y ?? 0,
            'duration': op.duration,
          });
          break;
        case OperationType.swipe:
          result = await platform.invokeMethod<bool>('swipe', {
            'startX': op.x ?? 0,
            'startY': op.y ?? 0,
            'endX': op.endX ?? 0,
            'endY': op.endY ?? 0,
          });
          break;
        case OperationType.scroll:
          result = await platform.invokeMethod<bool>('scroll', {
            'x': op.x ?? 540,
            'y': op.y ?? 1500,
          });
          break;
        case OperationType.back:
          result = await platform.invokeMethod<bool>('back');
          break;
        case OperationType.home:
          result = await platform.invokeMethod<bool>('home');
          break;
        case OperationType.input:
          result = await platform.invokeMethod<bool>('input', {
            'text': op.text ?? '',
          });
          break;
      }
      if (result == true) {
        debugPrint('AccessibilityService executed: ${op.type.name}');
        return true;
      }
      debugPrint('AccessibilityService returned false: ${op.type.name}');
      return false;
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
