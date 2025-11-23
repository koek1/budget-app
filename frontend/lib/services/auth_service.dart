import 'package:hive/hive.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class AuthService {
    // Register user locally
    static Future<User> register(String name, String email, String password) async {
        // Check if user already exists
        final box = Hive.box('userBox');
        final usersBox = Hive.box('usersBox');
        
        // Get all users to check for duplicate email
        final existingUsers = usersBox.values.toList();
        final userExists = existingUsers.any((u) => 
            (u as Map)['email']?.toString().toLowerCase() == email.toLowerCase());
        
        if (userExists) {
            throw Exception('User with this email already exists');
        }

        // Create new user
        final user = User(
            id: Uuid().v4(),
            name: name,
            email: email.toLowerCase(),
            password: password, // In a real app, hash this
            currency: 'R',
            monthlyBudget: 0,
        );

        // Save user to users box
        await usersBox.add(user.toJson());
        
        // Set as current user
        await LocalStorageService.saveUser(user);

        return user;
    }

    // Login user locally
    static Future<User?> login(String email, String password) async {
        final usersBox = Hive.box('usersBox');
        final users = usersBox.values.toList();
        
        // Find user by email
        final userData = users.firstWhere(
            (u) => (u as Map)['email']?.toString().toLowerCase() == email.toLowerCase(),
            orElse: () => null,
        );

        if (userData == null) {
            throw Exception('Invalid email or password');
        }

        final userMap = Map<String, dynamic>.from(userData);
        // In a real app, verify password hash here
        // For now, simple comparison
        if (userMap['password'] != password) {
            throw Exception('Invalid email or password');
        }

        final user = User.fromJson(userMap);
        await LocalStorageService.saveUser(user);

        return user;
    }

    static Future<void> logout() async {
        await LocalStorageService.clearUser();
    }

    static Future<bool> isLoggedIn() async {
        return await LocalStorageService.isLoggedIn();
    }

    static Future<String?> getUserId() async {
        final user = await LocalStorageService.getCurrentUser();
        return user?.id;
    }

    static Future<User?> getCurrentUser() async {
        return await LocalStorageService.getCurrentUser();
    }
}