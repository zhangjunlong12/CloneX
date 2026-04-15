enum OperationType {
  tap,
  longPress,
  swipe,
  input,
  scroll,
  back,
  home,
}

class Operation {
  final String id;
  final OperationType type;
  final double? x;
  final double? y;
  final double? endX;
  final double? endY;
  final String? text;
  final int duration;
  final DateTime timestamp;
  // Element-based targeting
  final String? elementText;
  final String? elementId;
  final String? elementDescription;

  Operation({
    required this.id,
    required this.type,
    this.x,
    this.y,
    this.endX,
    this.endY,
    this.text,
    this.duration = 0,
    required this.timestamp,
    this.elementText,
    this.elementId,
    this.elementDescription,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'endX': endX,
        'endY': endY,
        'text': text,
        'duration': duration,
        'timestamp': timestamp.toIso8601String(),
        'elementText': elementText,
        'elementId': elementId,
        'elementDescription': elementDescription,
      };

  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
        id: json['id'],
        type: OperationType.values.firstWhere((e) => e.name == json['type']),
        x: json['x']?.toDouble(),
        y: json['y']?.toDouble(),
        endX: json['endX']?.toDouble(),
        endY: json['endY']?.toDouble(),
        text: json['text'],
        duration: json['duration'] ?? 0,
        timestamp: DateTime.parse(json['timestamp']),
        elementText: json['elementText'],
        elementId: json['elementId'],
        elementDescription: json['elementDescription'],
      );

  String get typeDescription {
    switch (type) {
      case OperationType.tap:
        return '点击 (${x?.toStringAsFixed(0)}, ${y?.toStringAsFixed(0)})';
      case OperationType.longPress:
        return '长按 (${x?.toStringAsFixed(0)}, ${y?.toStringAsFixed(0)})';
      case OperationType.swipe:
        return '滑动 (${x?.toStringAsFixed(0)}, ${y?.toStringAsFixed(0)}) → (${endX?.toStringAsFixed(0)}, ${endY?.toStringAsFixed(0)})';
      case OperationType.input:
        return '输入: $text';
      case OperationType.scroll:
        return '滚动';
      case OperationType.back:
        return '返回';
      case OperationType.home:
        return '主页';
    }
  }
}
