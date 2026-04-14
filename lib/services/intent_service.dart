import '../models/operation.dart';
import '../models/intent.dart';

class IntentService {
  IntentAnalysis analyzeTask(List<Operation> operations) {
    if (operations.isEmpty) {
      return IntentAnalysis(
        summary: '空操作序列',
        steps: [],
      );
    }

    final steps = <String>[];
    final tapCount = operations.where((o) => o.type == OperationType.tap).length;
    final swipeCount = operations.where((o) => o.type == OperationType.swipe).length;
    final inputCount = operations.where((o) => o.type == OperationType.input).length;

    steps.add('执行了 $tapCount 次点击');
    if (swipeCount > 0) steps.add('执行了 $swipeCount 次滑动');
    if (inputCount > 0) steps.add('执行了 $inputCount 次输入');

    final firstTap = operations.firstWhere(
      (o) => o.type == OperationType.tap,
      orElse: () => operations.first,
    );

    if (firstTap.x != null && firstTap.y != null) {
      if (firstTap.y! < 300) {
        steps.add('首先点击了屏幕顶部区域（可能是状态栏或导航）');
      } else if (firstTap.y! > 1000) {
        steps.add('首先点击了屏幕底部区域（可能是导航栏或底部菜单）');
      } else {
        steps.add('首先点击了屏幕中部区域');
      }
    }

    final totalDuration = operations.last.timestamp.difference(operations.first.timestamp);
    if (totalDuration.inSeconds < 5) {
      steps.add('操作快速完成（${totalDuration.inSeconds}秒），可能是简单操作');
    } else if (totalDuration.inMinutes < 1) {
      steps.add('操作持续约${totalDuration.inSeconds}秒');
    } else {
      steps.add('操作持续约${totalDuration.inMinutes}分${totalDuration.inSeconds % 60}秒');
    }

    String summary;
    if (tapCount > 10) {
      summary = '复杂的多次点击操作序列';
    } else if (swipeCount > tapCount) {
      summary = '以滑动为主的浏览操作';
    } else if (inputCount > 0) {
      summary = '包含输入内容的操作';
    } else {
      summary = '简单的点击操作序列';
    }

    return IntentAnalysis(
      summary: summary,
      steps: steps,
      actionType: _classifyActionType(operations),
      confidence: 0.75,
    );
  }

  String _classifyActionType(List<Operation> operations) {
    final swipeCount = operations.where((o) => o.type == OperationType.swipe).length;
    final tapCount = operations.where((o) => o.type == OperationType.tap).length;
    final inputCount = operations.where((o) => o.type == OperationType.input).length;

    if (inputCount > 0 && inputCount >= tapCount) {
      return 'input';
    } else if (swipeCount > tapCount * 0.5) {
      return 'browse';
    } else if (tapCount > 5) {
      return 'complex_tap';
    } else {
      return 'simple_tap';
    }
  }
}
