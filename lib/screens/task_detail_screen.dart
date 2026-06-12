import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/playback_service.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late PlaybackService _playbackService;
  bool _isPlaying = false;
  int _currentStep = 0;
  int _totalSteps = 0;
  bool _elementServiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _playbackService = PlaybackService(
      onStatusChange: (status) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(status), duration: const Duration(seconds: 2)),
          );
          if (status == '重放完成' || status == '已停止') {
            setState(() => _isPlaying = false);
          }
        }
      },
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _currentStep = current;
            _totalSteps = total;
          });
        }
      },
    );
    _totalSteps = widget.task.operations.length;
    _checkElementService();
  }

  Future<void> _checkElementService() async {
    const channel = MethodChannel('com.clonex/element');
    try {
      final result = await channel.invokeMethod<bool>('isElementServiceEnabled');
      if (mounted) {
        setState(() => _elementServiceEnabled = result ?? false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _elementServiceEnabled = false);
      }
    }
  }

  @override
  void dispose() {
    _playbackService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '任务详情',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (widget.task.intentSummary != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.task.intentSummary!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.touch_app_outlined,
                      '${widget.task.operationCount} 步操作',
                    ),
                    const SizedBox(width: 24),
                    _buildInfoItem(
                      Icons.access_time,
                      dateFormat.format(widget.task.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.play_circle_outline,
                      '已执行 ${widget.task.playCount} 次',
                    ),
                    if (widget.task.lastPlayedAt != null) ...[
                      const SizedBox(width: 24),
                      _buildInfoItem(
                        Icons.update,
                        '上次: ${dateFormat.format(widget.task.lastPlayedAt!)}',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildAccessibilityStatus(),
              ],
            ),
          ),

          if (_isPlaying) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '正在执行 $_currentStep / $_totalSteps',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _totalSteps > 0 ? _currentStep / _totalSteps : 0,
                    backgroundColor: Colors.white,
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPlaying ? null : _startPlayback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      '开始执行',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_isPlaying) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _stopPlayback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('停止'),
                  ),
                ],
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '操作步骤',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.task.operations.length,
              itemBuilder: (context, index) {
                final op = widget.task.operations[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: index < _currentStep
                          ? const Color(0xFF3B82F6).withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index < _currentStep
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: index < _currentStep
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
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
                              style: TextStyle(
                                fontSize: 14,
                                color: index < _currentStep
                                    ? const Color(0xFF1A1A2E)
                                    : const Color(0xFF64748B),
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
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _elementServiceEnabled
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _elementServiceEnabled ? Icons.check_circle : Icons.warning,
            size: 16,
            color: _elementServiceEnabled
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Text(
            _elementServiceEnabled
                ? '元素级无障碍服务已连接'
                : '元素级无障碍服务未连接',
            style: TextStyle(
              fontSize: 12,
              color: _elementServiceEnabled
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Future<void> _startPlayback() async {
    setState(() {
      _isPlaying = true;
      _currentStep = 0;
    });
    await ref.read(tasksProvider.notifier).incrementPlayCount(widget.task.id);
    await _playbackService.play(widget.task);
  }

  void _stopPlayback() {
    _playbackService.stop();
    setState(() => _isPlaying = false);
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除任务'),
        content: Text('确定要删除 "${widget.task.name}" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(tasksProvider.notifier).deleteTask(widget.task.id);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}
