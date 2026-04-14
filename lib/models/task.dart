import 'operation.dart';

class Task {
  final String id;
  final String name;
  final String? description;
  final List<Operation> operations;
  final String? intentSummary;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final int playCount;

  Task({
    required this.id,
    required this.name,
    this.description,
    required this.operations,
    this.intentSummary,
    required this.createdAt,
    this.lastPlayedAt,
    this.playCount = 0,
  });

  Task copyWith({
    String? id,
    String? name,
    String? description,
    List<Operation>? operations,
    String? intentSummary,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    int? playCount,
  }) =>
      Task(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        operations: operations ?? this.operations,
        intentSummary: intentSummary ?? this.intentSummary,
        createdAt: createdAt ?? this.createdAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        playCount: playCount ?? this.playCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'operations': operations.map((o) => o.toJson()).toList(),
        'intentSummary': intentSummary,
        'createdAt': createdAt.toIso8601String(),
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'playCount': playCount,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        operations: (json['operations'] as List)
            .map((o) => Operation.fromJson(o))
            .toList(),
        intentSummary: json['intentSummary'],
        createdAt: DateTime.parse(json['createdAt']),
        lastPlayedAt: json['lastPlayedAt'] != null
            ? DateTime.parse(json['lastPlayedAt'])
            : null,
        playCount: json['playCount'] ?? 0,
      );

  int get operationCount => operations.length;

  Duration get totalDuration {
    if (operations.isEmpty) return Duration.zero;
    final last = operations.last.timestamp;
    final first = operations.first.timestamp;
    return last.difference(first);
  }
}
