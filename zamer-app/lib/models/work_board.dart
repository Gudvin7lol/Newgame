import 'dart:math' as math;

/// Project-owned work records. They travel with the project's JSON/ZIP backup.
class WorkBoard {
  WorkBoard({List<WorkTask>? tasks, List<WorkIssue>? issues, List<WorkLog>? events})
      : tasks = tasks ?? [],
        issues = issues ?? [],
        events = events ?? [];

  final List<WorkTask> tasks;
  final List<WorkIssue> issues;
  final List<WorkLog> events;

  double get actualProgress => _weighted((task) => task.progress);
  double get acceptedProgress => _weighted((task) => task.acceptedProgress);

  // Planned completion is a comparison metric, not a mutation of the baseline.
  double plannedProgress(DateTime at) => _weighted((task) {
        final start = task.baselineStart.millisecondsSinceEpoch;
        final finish = task.baselineFinish.add(const Duration(days: 1)).millisecondsSinceEpoch;
        if (finish <= start) return at.isAfter(task.baselineFinish) ? 1 : 0;
        return ((at.millisecondsSinceEpoch - start) / (finish - start))
            .clamp(0.0, 1.0);
      });

  double _weighted(double Function(WorkTask) portion) {
    final weight = tasks.fold<double>(0, (sum, task) => sum + math.max(0.1, task.hours));
    if (weight == 0) return 0;
    return tasks.fold<double>(0, (sum, task) =>
        sum + math.max(0.1, task.hours) * portion(task)) / weight;
  }

  void log(String description, {String? taskId}) {
    events.insert(0, WorkLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      text: description,
      taskId: taskId,
    ));
  }

  Map<String, dynamic> toJson() => {
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'issues': issues.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory WorkBoard.fromJson(Map<String, dynamic> json) => WorkBoard(
        tasks: ((json['tasks'] as List?) ?? const [])
            .map((e) => WorkTask.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        issues: ((json['issues'] as List?) ?? const [])
            .map((e) => WorkIssue.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        events: ((json['events'] as List?) ?? const [])
            .map((e) => WorkLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class WorkTask {
  WorkTask({
    required this.id,
    required this.title,
    required this.start,
    required this.finish,
    DateTime? baselineStart,
    DateTime? baselineFinish,
    required this.quantity,
    required this.unit,
    required this.hours,
    this.floorId,
    this.roomId,
    this.roomName = '',
    this.assignee = '',
    this.category = 'Отделка',
    this.predecessorId,
    this.done = 0,
    this.accepted = 0,
    this.paused = false,
  }) : baselineStart = baselineStart ?? start,
       baselineFinish = baselineFinish ?? finish;

  final DateTime baselineStart, baselineFinish;
  final String id;
  String title, unit, category, assignee, roomName;
  String? floorId, roomId, predecessorId;
  DateTime start, finish;
  double quantity, done, accepted, hours;
  bool paused;

  double get progress => quantity <= 0 ? 0 : (done / quantity).clamp(0, 1).toDouble();
  double get acceptedProgress =>
      quantity <= 0 ? 0 : (accepted / quantity).clamp(0, 1).toDouble();
  bool get fullyAccepted => quantity > 0 && accepted >= quantity - 0.0001;
  bool get complete => quantity > 0 && done >= quantity - 0.0001;

  bool isDelayed(DateTime now) =>
      now.isAfter(DateTime(finish.year, finish.month, finish.day, 23, 59, 59)) &&
      !complete;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'finish': finish.toIso8601String(),
        'baselineStart': baselineStart.toIso8601String(),
        'baselineFinish': baselineFinish.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'hours': hours,
        'floorId': floorId,
        'roomId': roomId,
        'roomName': roomName,
        'assignee': assignee,
        'category': category,
        'predecessorId': predecessorId,
        'done': done,
        'accepted': accepted,
        'paused': paused,
      };

  factory WorkTask.fromJson(Map<String, dynamic> json) => WorkTask(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Работа',
        start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
        finish: DateTime.tryParse(json['finish']?.toString() ?? '') ?? DateTime.now(),
        baselineStart: DateTime.tryParse(json['baselineStart']?.toString() ?? ''),
        baselineFinish: DateTime.tryParse(json['baselineFinish']?.toString() ?? ''),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit']?.toString() ?? 'м²',
        hours: (json['hours'] as num?)?.toDouble() ?? 1,
        floorId: json['floorId']?.toString(),
        roomId: json['roomId']?.toString(),
        roomName: json['roomName']?.toString() ?? '',
        assignee: json['assignee']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Отделка',
        predecessorId: json['predecessorId']?.toString(),
        done: (json['done'] as num?)?.toDouble() ?? 0,
        accepted: (json['accepted'] as num?)?.toDouble() ?? 0,
        paused: json['paused'] == true,
      );
}

class WorkIssue {
  WorkIssue({
    required this.id,
    required this.title,
    required this.createdAt,
    this.taskId,
    this.roomId,
    this.roomName = '',
    this.description = '',
    this.responsible = '',
    this.priority = 'Средняя',
    this.due,
    this.closedAt,
  });

  final String id;
  String title, description, roomName, responsible, priority;
  String? taskId, roomId;
  DateTime createdAt;
  DateTime? due, closedAt;
  bool get open => closedAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'taskId': taskId,
        'roomId': roomId,
        'roomName': roomName,
        'description': description,
        'responsible': responsible,
        'priority': priority,
        'due': due?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
      };

  factory WorkIssue.fromJson(Map<String, dynamic> json) => WorkIssue(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Замечание',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        taskId: json['taskId']?.toString(),
        roomId: json['roomId']?.toString(),
        roomName: json['roomName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        responsible: json['responsible']?.toString() ?? '',
        priority: json['priority']?.toString() ?? 'Средняя',
        due: DateTime.tryParse(json['due']?.toString() ?? ''),
        closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? ''),
      );
}

class WorkLog {
  WorkLog({required this.id, required this.timestamp, required this.text, this.taskId});
  final String id, text;
  final DateTime timestamp;
  final String? taskId;
  Map<String, dynamic> toJson() => {
        'id': id, 'timestamp': timestamp.toIso8601String(), 'text': text, 'taskId': taskId,
      };
  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
        id: json['id']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
        text: json['text']?.toString() ?? '',
        taskId: json['taskId']?.toString(),
      );
}
