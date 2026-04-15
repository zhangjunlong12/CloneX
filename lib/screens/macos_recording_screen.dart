import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/mac_operation.dart';
import '../models/operation.dart';
import '../services/macos_automation_service.dart';
import '../providers/task_provider.dart';

class MacOSRecordingScreen extends ConsumerStatefulWidget {
  const MacOSRecordingScreen({super.key});

  @override
  ConsumerState<MacOSRecordingScreen> createState() => _MacOSRecordingScreenState();
}

class _MacOSRecordingScreenState extends ConsumerState<MacOSRecordingScreen> {
  final MacOSAutomationService _automationService = MacOSAutomationService();
  bool _isRecording = false;
  final List<MacOperation> _recordedOperations = [];
  DateTime? _recordingStartTime;
  int _clickCount = 0;
  int _keyCount = 0;

  final _taskNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _automationService.onRecordingStateChanged = (recording) {
      if (mounted) {
        setState(() => _isRecording = recording);
      }
    };
    _automationService.onStatusChange = (status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status), duration: const Duration(seconds: 2)),
        );
      }
    };
  }

  @override
  void dispose() {
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
          '录制操作 (macOS)',
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
                              if (op.title != null || op.role != null)
                                Text(
                                  _buildElementInfo(op),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF10B981),
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
                        '提示：请确保已在系统设置中授权无障碍权限',
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _recordedOperations.isEmpty || _isRecording
                          ? null
                          : _testPlayback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '测试回放',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildElementInfo(MacOperation op) {
    final parts = <String>[];
    if (op.title != null && op.title!.isNotEmpty) {
      parts.add('标题:${op.title}');
    }
    if (op.role != null && op.role!.isNotEmpty) {
      parts.add('类型:${op.role}');
    }
    if (op.value != null && op.value!.isNotEmpty) {
      parts.add('值:${op.value}');
    }
    return parts.join(' | ');
  }

  Color _getOperationColor(MacOperationType type) {
    switch (type) {
      case MacOperationType.mouseDown:
      case MacOperationType.mouseUp:
      case MacOperationType.mouseClick:
        return const Color(0xFF3B82F6);
      case MacOperationType.rightClick:
        return const Color(0xFFF59E0B);
      case MacOperationType.scroll:
        return const Color(0xFF10B981);
      case MacOperationType.keyDown:
      case MacOperationType.keyUp:
        return const Color(0xFF8B5CF6);
      case MacOperationType.type:
        return const Color(0xFF06B6D4);
      case MacOperationType.move:
        return const Color(0xFF64748B);
    }
  }

  IconData _getOperationIcon(MacOperationType type) {
    switch (type) {
      case MacOperationType.mouseDown:
      case MacOperationType.mouseUp:
      case MacOperationType.mouseClick:
        return Icons.touch_app;
      case MacOperationType.rightClick:
        return Icons.mouse;
      case MacOperationType.scroll:
        return Icons.sync;
      case MacOperationType.keyDown:
      case MacOperationType.keyUp:
        return Icons.keyboard;
      case MacOperationType.type:
        return Icons.text_fields;
      case MacOperationType.move:
        return Icons.open_with;
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
        _buildStatItem('点击', _clickCount),
        Container(
          width: 1,
          height: 40,
          color: const Color(0xFFE2E8F0),
        ),
        _buildStatItem('按键', _keyCount),
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

  void _toggleRecording() async {
    if (_isRecording) {
      await _automationService.stopRecording();
      await _automationService.getRecordedEvents();
      setState(() {
        _recordedOperations.clear();
        _recordedOperations.addAll(_automationService.recordedOperations);
        _recordingStartTime = null;
      });
    } else {
      final started = await _automationService.startRecording();
      if (started) {
        setState(() {
          _recordedOperations.clear();
          _recordingStartTime = DateTime.now();
          _clickCount = 0;
          _keyCount = 0;
        });
      }
    }
  }

  void _removeOperation(int index) {
    setState(() {
      _recordedOperations.removeAt(index);
    });
  }

  void _clearOperations() {
    setState(() {
      _recordedOperations.clear();
      _clickCount = 0;
      _keyCount = 0;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _testPlayback() async {
    if (_recordedOperations.isEmpty) return;

    final success = await _automationService.play(_recordedOperations);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回放失败，请检查无障碍权限')),
      );
    }
  }

  void _handleClose(BuildContext context) {
    if (_isRecording) {
      _automationService.stopRecording();
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

              // 将 MacOperation 转换为 Operation（兼容现有存储）
              final operations = _recordedOperations.map((macOp) {
                return Operation(
                  id: const Uuid().v4(),
                  type: _macOpTypeToOpType(macOp.type),
                  x: macOp.x,
                  y: macOp.y,
                  timestamp: macOp.timestamp,
                );
              }).toList();

              await ref.read(tasksProvider.notifier).addTask(
                    name: name,
                    operations: operations,
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

  OperationType _macOpTypeToOpType(MacOperationType type) {
    switch (type) {
      case MacOperationType.mouseClick:
      case MacOperationType.mouseDown:
        return OperationType.tap;
      case MacOperationType.rightClick:
        return OperationType.tap;
      case MacOperationType.scroll:
        return OperationType.scroll;
      case MacOperationType.type:
        return OperationType.input;
      case MacOperationType.keyDown:
      case MacOperationType.keyUp:
        return OperationType.input;
      default:
        return OperationType.tap;
    }
  }
}
