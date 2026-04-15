import 'package:uuid/uuid.dart';

enum WindowsOperationType {
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

class WindowsOperation {
  final String id;
  final WindowsOperationType type;
  final double? x;
  final double? y;
  final double? deltaY;
  final int? keyCode;
  final String? characters;
  final String? text;
  final String? button;
  final String? name;
  final String? role;
  final String? value;
  final String? description;
  final Map<String, double>? bounds;
  final DateTime timestamp;
  final double? delay;

  WindowsOperation({
    String? id,
    required this.type,
    this.x,
    this.y,
    this.deltaY,
    this.keyCode,
    this.characters,
    this.text,
    this.button,
    this.name,
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
      case WindowsOperationType.mouseDown:
        return '鼠标按下 (${button ?? "left"})';
      case WindowsOperationType.mouseUp:
        return '鼠标释放 (${button ?? "left"})';
      case WindowsOperationType.mouseClick:
        return '鼠标点击';
      case WindowsOperationType.rightClick:
        return '右键点击';
      case WindowsOperationType.scroll:
        return '滚动 ${deltaY != null ? (deltaY! > 0 ? "↓" : "↑") : ""}';
      case WindowsOperationType.keyDown:
        return '按键按下 ${_keyCodeToString(keyCode)}';
      case WindowsOperationType.keyUp:
        return '按键释放 ${_keyCodeToString(keyCode)}';
      case WindowsOperationType.type:
        return '输入: $text';
      case WindowsOperationType.move:
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
      'name': name,
      'role': role,
      'value': value,
      'description': description,
      'bounds': bounds,
      'timestamp': timestamp.toIso8601String(),
      'delay': delay,
    };
  }

  factory WindowsOperation.fromJson(Map<String, dynamic> json) {
    return WindowsOperation(
      id: json['id'] as String?,
      type: _typeFromString(json['type'] as String),
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      deltaY: (json['deltaY'] as num?)?.toDouble(),
      keyCode: json['keyCode'] as int?,
      characters: json['characters'] as String?,
      text: json['text'] as String?,
      button: json['button'] as String?,
      name: json['name'] as String?,
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

  String _typeToString(WindowsOperationType type) {
    switch (type) {
      case WindowsOperationType.mouseDown:
        return 'mouseDown';
      case WindowsOperationType.mouseUp:
        return 'mouseUp';
      case WindowsOperationType.mouseClick:
        return 'click';
      case WindowsOperationType.rightClick:
        return 'rightClick';
      case WindowsOperationType.scroll:
        return 'scroll';
      case WindowsOperationType.keyDown:
        return 'keyDown';
      case WindowsOperationType.keyUp:
        return 'keyUp';
      case WindowsOperationType.type:
        return 'type';
      case WindowsOperationType.move:
        return 'move';
    }
  }

  WindowsOperationType _typeFromString(String type) {
    switch (type) {
      case 'mouseDown':
        return WindowsOperationType.mouseDown;
      case 'mouseUp':
        return WindowsOperationType.mouseUp;
      case 'click':
        return WindowsOperationType.mouseClick;
      case 'rightClick':
        return WindowsOperationType.rightClick;
      case 'scroll':
        return WindowsOperationType.scroll;
      case 'keyDown':
        return WindowsOperationType.keyDown;
      case 'keyUp':
        return WindowsOperationType.keyUp;
      case 'type':
        return WindowsOperationType.type;
      case 'move':
        return WindowsOperationType.move;
      default:
        return WindowsOperationType.mouseClick;
    }
  }

  String? _keyCodeToString(int? keyCode) {
    if (keyCode == null) return null;
    // 常见虚拟键码映射
    const keyMap = {
      0x41: 'A', 0x42: 'B', 0x43: 'C', 0x44: 'D', 0x45: 'E',
      0x46: 'F', 0x47: 'G', 0x48: 'H', 0x49: 'I', 0x4A: 'J',
      0x4B: 'K', 0x4C: 'L', 0x4D: 'M', 0x4E: 'N', 0x4F: 'O',
      0x50: 'P', 0x51: 'Q', 0x52: 'R', 0x53: 'S', 0x54: 'T',
      0x55: 'U', 0x56: 'V', 0x57: 'W', 0x58: 'X', 0x59: 'Y',
      0x5A: 'Z',
      0x30: '0', 0x31: '1', 0x32: '2', 0x33: '3', 0x34: '4',
      0x35: '5', 0x36: '6', 0x37: '7', 0x38: '8', 0x39: '9',
      0x0D: 'Enter', 0x09: 'Tab', 0x20: 'Space', 0x08: 'Backspace',
      0x1B: 'Escape', 0x70: 'F1', 0x71: 'F2', 0x72: 'F3',
      0x25: 'Left', 0x26: 'Up', 0x27: 'Right', 0x28: 'Down',
    };
    return keyMap[keyCode] ?? 'Key$keyCode';
  }
}
