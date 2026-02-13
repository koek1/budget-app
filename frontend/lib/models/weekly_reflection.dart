import 'package:hive/hive.dart';

part 'weekly_reflection.g.dart';

@HiveType(typeId: 5)
class WeeklyReflection {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime weekStarting;

  @HiveField(3)
  final String wentWell;

  @HiveField(4)
  final String regret;

  @HiveField(5)
  final String nextWeekGoal;

  @HiveField(6)
  final DateTime createdAt;

  WeeklyReflection({
    required this.id,
    required this.userId,
    required this.weekStarting,
    required this.wentWell,
    required this.regret,
    required this.nextWeekGoal,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'weekStarting': weekStarting.toIso8601String(),
      'wentWell': wentWell,
      'regret': regret,
      'nextWeekGoal': nextWeekGoal,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WeeklyReflection.fromJson(Map<String, dynamic> json) {
    return WeeklyReflection(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      weekStarting: json['weekStarting'] != null
          ? DateTime.parse(json['weekStarting'])
          : DateTime.now(),
      wentWell: json['wentWell'] ?? '',
      regret: json['regret'] ?? '',
      nextWeekGoal: json['nextWeekGoal'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
