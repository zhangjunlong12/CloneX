import 'package:uuid/uuid.dart';

enum MacOperationType {
  mouseDown,
  mouseUp,
  mouseClick,
  rightClick,
  scroll,
  keyDown,
  keyUp,
  type,
  move,
}

class MacOperation {
  final String id;
  final MacOperationType type;
  final double? x;
  final double? y;
  final double? deltaY;
  final int? keyCode;
  final String? characters;
  final String? text;
  final String? button;
  final String? title;
  final String? role;
  final String? value;
  final String? description;
  final Map<String, double>? bounds;
  final DateTime timestamp;
  final double? delay;

  MacOperation({
    String? id,
    required this.type,
    this.x,
    this.y,
    this.deltaY,
    this.keyCode,
    this.characters,
    this.text,
    this.button,
    this.title,
    this.role,
    this.value,
    this.description,
    this.bounds,
    DateTime? timestamp,
    this.delay,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  String get typeDescription {
    switch (type) {
      case MacOperationType.mouseDown:
        return '鼠标按下 (${button ?? "left"})';
      case MacOperationType.mouseUp:
        return '鼠标释放 (${button ?? "left"})';
      case MacOperationType.mouseClick:
        return '鼠标点击';
      case MacOperationType.rightClick:
        return '右键点击';
      case MacOperationType.scroll:
        return '滚动 ${deltaY != null ? (deltaY! > 0 ? "↓" : "↑") : ""}';
      case MacOperationType.keyDown:
        return '按键按下 ${_keyCodeToString(keyCode)}';
      case MacOperationType.keyUp:
        return '按键释放 ${_keyCodeToString(keyCode)}';
      case MacOperationType.type:
        return '输入: $text';
      case MacOperationType.move:
        return '移动到 ($x, $y)';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': _typeToString(type),
      'x': x,
      'y': y,
      'deltaY': deltaY,
      'keyCode': keyCode,
      'characters': characters,
      'text': text,
      'button': button,
      'title': title,
      'role': role,
      'value': value,
      'description': description,
      'bounds': bounds,
      'timestamp': timestamp.toIso8601String(),
      'delay': delay,
    };
  }

  factory MacOperation.fromJson(Map<String, dynamic> json) {
    return MacOperation(
      id: json['id'] as String?,
      type: _typeFromString(json['type'] as String),
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      deltaY: (json['deltaY'] as num?)?.toDouble(),
      keyCode: json['keyCode'] as int?,
      characters: json['characters'] as String?,
      text: json['text'] as String?,
      button: json['button'] as String?,
      title: json['title'] as String?,
      role: json['role'] as String?,
      value: json['value'] as String?,
      description: json['description'] as String?,
      bounds: json['bounds'] != null
          ? Map<String, double>.from(json['bounds'] as Map)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      delay: (json['delay'] as num?)?.toDouble(),
    );
  }

  String _typeToString(MacOperationType type) {
    switch (type) {
      case MacOperationType.mouseDown:
        return 'mouseDown';
      case MacOperationType.mouseUp:
        return 'mouseUp';
      case MacOperationType.mouseClick:
        return 'click';
      case MacOperationType.rightClick:
        return 'rightClick';
      case MacOperationType.scroll:
        return 'scroll';
      case MacOperationType.keyDown:
        return 'keyDown';
      case MacOperationType.keyUp:
        return 'keyUp';
      case MacOperationType.type:
        return 'type';
      case MacOperationType.move:
        return 'move';
    }
  }

  MacOperationType _typeFromString(String type) {
    switch (type) {
      case 'mouseDown':
        return MacOperationType.mouseDown;
      case 'mouseUp':
        return MacOperationType.mouseUp;
      case 'click':
        return MacOperationType.mouseClick;
      case 'rightClick':
        return MacOperationType.rightClick;
      case 'scroll':
        return MacOperationType.scroll;
      case 'keyDown':
        return MacOperationType.keyDown;
      case 'keyUp':
        return MacOperationType.keyUp;
      case 'type':
        return MacOperationType.type;
      case 'move':
        return MacOperationType.move;
      default:
        return MacOperationType.mouseClick;
    }
  }

  String? _keyCodeToString(int? keyCode) {
    if (keyCode == null) return null;
    // 常见键码映射
    const keyMap = {
      0: 'A', 1: 'S', 2: 'D', 3: 'F', 4: 'H', 5: 'G', 6: 'Z', 7: 'X',
      8: 'C', 9: 'V', 11: 'B', 12: 'Q', 13: 'W', 14: 'E', 15: 'R',
      16: 'Y', 17: 'T', 18: '1', 19: '2', 20: '3', 21: '4', 22: '6',
      23: '5', 24: '=', 25: '9', 26: '7', 27: '-', 28: '8', 29: '0',
      30: ']', 31: 'O', 32: 'U', 33: '[', 34: 'I', 35: 'P', 36: 'Return',
      37: 'L', 38: 'J', 39: "'", 40: 'K', 41: ';', 42: '\\', 43: ',',
      44: '/', 45: 'N', 46: 'M', 47: '.', 48: 'Tab', 49: 'Space',
      50: '`', 51: 'Delete', 53: 'Escape',
      36: 'Return', 48: 'Tab', 49: 'Space', 51: 'Delete',
      123: '←', 124: '→', 125: '↓', 126: '↑',
    };
    return keyMap[keyCode] ?? 'Key$keyCode';
  }
}
