import 'package:flutter/services.dart';
import '../models/windows_operation.dart';

class WindowsAutomationService {
  static const _channel = MethodChannel('com.clonex/windows_automation');

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  final List<WindowsOperation> _recordedOperations = [];
  List<WindowsOperation> get recordedOperations => List.unmodifiable(_recordedOperations);

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // 录制状态回调
  void Function(bool recording)? onRecordingStateChanged;

  // 事件回调（用于实时显示录制的事件）
  void Function(WindowsOperation operation)? onOperationRecorded;

  // 回放进度回调
  void Function(int current, int total)? onPlaybackProgress;

  // 状态消息回调
  void Function(String status)? onStatusChange;

  /// 开始录制
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    try {
      final result = await _channel.invokeMethod<bool>('startRecording');
      if (result == true) {
        _isRecording = true;
        _recordedOperations.clear();
        onRecordingStateChanged?.call(true);
        onStatusChange?.call('开始录制...');
        return true;
      }
      return false;
    } catch (e) {
      onStatusChange?.call('录制失败: $e');
      return false;
    }
  }

  /// 停止录制
  Future<bool> stopRecording() async {
    if (!_isRecording) return false;

    try {
      final result = await _channel.invokeMethod<bool>('stopRecording');
      if (result == true) {
        _isRecording = false;
        onRecordingStateChanged?.call(false);
        onStatusChange?.call('录制完成，共 ${_recordedOperations.length} 个操作');
        return true;
      }
      return false;
    } catch (e) {
      onStatusChange?.call('停止录制失败: $e');
      return false;
    }
  }

  /// 获取录制的事件
  Future<List<WindowsOperation>> getRecordedEvents() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getRecordedEvents');
      if (result != null) {
        final operations = result
            .map((e) => WindowsOperation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _recordedOperations.clear();
        _recordedOperations.addAll(operations);
        return operations;
      }
      return [];
    } catch (e) {
      onStatusChange?.call('获取事件失败: $e');
      return [];
    }
  }

  /// 回放操作序列
  Future<bool> play(List<WindowsOperation> operations) async {
    if (_isPlaying) return false;

    _isPlaying = true;
    onStatusChange?.call('开始回放...');

    try {
      // 将操作转换为 JSON
      final operationsJson = operations.map((op) => op.toJson()).toList();

      // 计算间隔时间
      for (int i = 0; i < operationsJson.length - 1; i++) {
        final current = operations[i];
        final next = operations[i + 1];
        final delay = next.timestamp.difference(current.timestamp).inMilliseconds.toDouble();
        if (delay > 0 && delay < 5000) {
          operationsJson[i]['delay'] = delay;
        }
      }

      final result = await _channel.invokeMethod<bool>('play', operationsJson);
      onPlaybackProgress?.call(operations.length, operations.length);
      onStatusChange?.call('回放完成');
      return result ?? false;
    } catch (e) {
      onStatusChange?.call('回放失败: $e');
      return false;
    } finally {
      _isPlaying = false;
    }
  }

  /// 在指定坐标查找元素
  Future<Map<String, dynamic>?> findElementAt(double x, double y) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('findElementAt', {
        'x': x,
        'y': y,
      });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查无障碍权限是否启用
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 停止回放
  void stop() {
    _isPlaying = false;
    onStatusChange?.call('已停止');
  }
}
