import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String description;
  @HiveField(3)
  DateTime date;
  @HiveField(4)
  String source; // 'manual' or 'canvas'
  @HiveField(5)
  bool isCompleted;
  @HiveField(6)
  String notes; // <-- Add this field

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.source = 'manual',
    this.isCompleted = false,
    this.notes = '', // <-- Add this default
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'source': source,
        'isCompleted': isCompleted,
        'notes': notes, // <-- Add this
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        date: DateTime.parse(json['date']),
        source: json['source'] ?? 'manual',
        isCompleted: json['isCompleted'] ?? false,
        notes: json['notes'] ?? '', // <-- Add this
      );
}
