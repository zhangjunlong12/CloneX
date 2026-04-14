class IntentAnalysis {
  final String summary;
  final List<String> steps;
  final String? targetApp;
  final String? actionType;
  final double confidence;

  IntentAnalysis({
    required this.summary,
    required this.steps,
    this.targetApp,
    this.actionType,
    this.confidence = 0.8,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'steps': steps,
        'targetApp': targetApp,
        'actionType': actionType,
        'confidence': confidence,
      };

  factory IntentAnalysis.fromJson(Map<String, dynamic> json) => IntentAnalysis(
        summary: json['summary'],
        steps: List<String>.from(json['steps']),
        targetApp: json['targetApp'],
        actionType: json['actionType'],
        confidence: json['confidence']?.toDouble() ?? 0.8,
      );
}
