import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  String? password;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final double monthlyBudget;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    this.currency = 'R',
    this.monthlyBudget = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'name': name,
      'email': email,
      'password': password, // Include password for authentication
      'currency': currency,
      'monthlyBudget': monthlyBudget,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      password: json['password']?.toString(), // Include password if present
      currency: json['currency'] ?? 'R',
      monthlyBudget: (json['monthlyBudget'] ?? 0).toDouble(),
    );
  }
}

