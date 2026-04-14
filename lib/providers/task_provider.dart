import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/operation.dart';
import '../services/storage_service.dart';
import '../services/intent_service.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider((ref) => StorageService());
final intentServiceProvider = Provider((ref) => IntentService());
final uuidProvider = Provider((ref) => const Uuid());

final tasksProvider = StateNotifierProvider<TasksNotifier, AsyncValue<List<Task>>>((ref) {
  return TasksNotifier(ref);
});

class TasksNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final Ref _ref;

  TasksNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final tasks = await _ref.read(storageServiceProvider).getAllTasks();
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTask({
    required String name,
    String? description,
    required List<Operation> operations,
  }) async {
    final intentService = _ref.read(intentServiceProvider);
    final analysis = intentService.analyzeTask(operations);

    final task = Task(
      id: _ref.read(uuidProvider).v4(),
      name: name,
      description: description,
      operations: operations,
      intentSummary: analysis.summary,
      createdAt: DateTime.now(),
    );

    await _ref.read(storageServiceProvider).saveTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    await _ref.read(storageServiceProvider).deleteTask(id);
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _ref.read(storageServiceProvider).updateTask(task);
    await loadTasks();
  }

  Future<void> incrementPlayCount(String id) async {
    final task = await _ref.read(storageServiceProvider).getTaskById(id);
    if (task != null) {
      final updated = task.copyWith(
        playCount: task.playCount + 1,
        lastPlayedAt: DateTime.now(),
      );
      await _ref.read(storageServiceProvider).updateTask(updated);
      await loadTasks();
    }
  }
}

final currentRecordingProvider = StateProvider<List<Operation>>((ref) => []);

final isRecordingProvider = StateProvider<bool>((ref) => false);

final playbackStatusProvider = StateProvider<String?>((ref) => null);

final playbackProgressProvider = StateProvider<(int, int)?>((ref) => null);
