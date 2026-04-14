import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/operation.dart';
import '../providers/task_provider.dart';
import 'package:intl/intl.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _isRecording = false;
  final List<Operation> _recordedOperations = [];
  DateTime? _recordingStartTime;
  int _tapCount = 0;
  int _swipeCount = 0;
  Timer? _recordingTimer;
  final Random _random = Random();

  final _taskNameController = TextEditingController();
  static const _channel = MethodChannel('com.clonex/recording');

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _taskNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          onPressed: () => _handleClose(context),
        ),
        title: const Text(
          '录制操作',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildRecordingIndicator(),
                const SizedBox(height: 24),
                _buildRecordButton(),
                const SizedBox(height: 24),
                _buildStats(),
              ],
            ),
          ),

          if (_recordedOperations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '已录制的操作',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearOperations,
                    child: const Text(
                      '清空',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recordedOperations.length,
                itemBuilder: (context, index) {
                  final op = _recordedOperations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _getOperationColor(op.type),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              _getOperationIcon(op.type),
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                op.typeDescription,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                DateFormat('HH:mm:ss').format(op.timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () => _removeOperation(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '点击上方按钮开始录制',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '提示：请确保已开启无障碍服务权限',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _recordedOperations.isEmpty || _isRecording
                      ? null
                      : () => _showSaveDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '保存任务',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getOperationColor(OperationType type) {
    switch (type) {
      case OperationType.tap:
        return const Color(0xFF3B82F6);
      case OperationType.longPress:
        return const Color(0xFFF59E0B);
      case OperationType.swipe:
        return const Color(0xFF10B981);
      case OperationType.input:
        return const Color(0xFF8B5CF6);
      case OperationType.scroll:
        return const Color(0xFF06B6D4);
      case OperationType.back:
      case OperationType.home:
        return const Color(0xFF64748B);
    }
  }

  IconData _getOperationIcon(OperationType type) {
    switch (type) {
      case OperationType.tap:
        return Icons.touch_app;
      case OperationType.longPress:
        return Icons.touch_app_outlined;
      case OperationType.swipe:
        return Icons.swipe;
      case OperationType.input:
        return Icons.keyboard;
      case OperationType.scroll:
        return Icons.sync;
      case OperationType.back:
        return Icons.arrow_back;
      case OperationType.home:
        return Icons.home;
    }
  }

  Widget _buildRecordingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _isRecording ? '正在录制...' : '等待开始',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF64748B),
          ),
        ),
        if (_recordingStartTime != null) ...[
          const SizedBox(width: 16),
          Text(
            _formatDuration(DateTime.now().difference(_recordingStartTime!)),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                  .withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.fiber_manual_record,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('点击', _tapCount),
        Container(
          width: 1,
          height: 40,
          color: const Color(0xFFE2E8F0),
        ),
        _buildStatItem('滑动', _swipeCount),
        Container(
          width: 1,
          height: 40,
          color: const Color(0xFFE2E8F0),
        ),
        _buildStatItem('总计', _recordedOperations.length),
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordingStartTime = DateTime.now();
        _recordedOperations.clear();
        _tapCount = 0;
        _swipeCount = 0;
      }
    });

    if (_isRecording) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }

  void _startRecording() async {
    try {
      await _channel.invokeMethod('startRecording');
    } catch (e) {
      debugPrint('Failed to start native recording: $e');
    }
    _startSimulatedRecording();
  }

  void _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      await _channel.invokeMethod('stopRecording');
    } catch (e) {
      debugPrint('Failed to stop native recording: $e');
    }
  }

  void _startSimulatedRecording() {
    // 模拟录制 - 生成随机操作
    // 注意：真正的触摸录制需要 Android 端实现触摸监听
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isRecording || !mounted) {
        timer.cancel();
        return;
      }

      final opType = _random.nextInt(10);
      Operation op;

      if (opType < 6) {
        // 60% 概率点击
        op = Operation(
          id: const Uuid().v4(),
          type: OperationType.tap,
          x: 200 + _random.nextInt(800).toDouble(),
          y: 400 + _random.nextInt(1200).toDouble(),
          timestamp: DateTime.now(),
        );
      } else if (opType < 9) {
        // 30% 概率滑动
        final startX = 200 + _random.nextInt(800).toDouble();
        final startY = 600 + _random.nextInt(800).toDouble();
        op = Operation(
          id: const Uuid().v4(),
          type: OperationType.swipe,
          x: startX,
          y: startY,
          endX: startX + _random.nextInt(400).toDouble() - 200,
          endY: startY + _random.nextInt(600).toDouble() - 300,
          timestamp: DateTime.now(),
        );
      } else {
        // 10% 概率滚动
        op = Operation(
          id: const Uuid().v4(),
          type: OperationType.scroll,
          x: 540,
          y: 1500,
          timestamp: DateTime.now(),
        );
      }

      _addOperation(op);
    });
  }

  void _addOperation(Operation op) {
    if (!_isRecording) return;
    setState(() {
      _recordedOperations.add(op);
      if (op.type == OperationType.tap || op.type == OperationType.longPress) {
        _tapCount++;
      }
      if (op.type == OperationType.swipe || op.type == OperationType.scroll) {
        _swipeCount++;
      }
    });
  }

  void _removeOperation(int index) {
    setState(() {
      final op = _recordedOperations.removeAt(index);
      if (op.type == OperationType.tap || op.type == OperationType.longPress) {
        _tapCount--;
      }
      if (op.type == OperationType.swipe || op.type == OperationType.scroll) {
        _swipeCount--;
      }
    });
  }

  void _clearOperations() {
    setState(() {
      _recordedOperations.clear();
      _tapCount = 0;
      _swipeCount = 0;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleClose(BuildContext context) {
    if (_isRecording) {
      _stopRecording();
    }
    if (_recordedOperations.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('放弃录制？'),
          content: const Text('当前录制的操作尚未保存，确定要放弃吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                '放弃',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showSaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('保存任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _taskNameController,
              decoration: InputDecoration(
                labelText: '任务名称',
                hintText: '例如：每日打卡',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _taskNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入任务名称')),
                );
                return;
              }

              await ref.read(tasksProvider.notifier).addTask(
                    name: name,
                    operations: List.from(_recordedOperations),
                  );

              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('任务已保存')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
