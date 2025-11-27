import 'package:hive/hive.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class AuthService {
    // Register user locally
    static Future<User> register(String username, String password) async {
        // Check if user already exists
        final usersBox = Hive.box('usersBox');
        
        // Get all users to check for duplicate username
        final existingUsers = usersBox.values.toList();
        final userExists = existingUsers.any((u) => 
            (u as Map)['name']?.toString().toLowerCase() == username.toLowerCase());
        
        if (userExists) {
            throw Exception('Username already exists');
        }

        // Create new user (using username as name, and empty email)
        final user = User(
            id: Uuid().v4(),
            name: username,
            email: '', // Email not required
            password: password, // In a real app, hash this
            currency: 'R',
            monthlyBudget: 0,
        );

        // Save user to users box
        await usersBox.add(user.toJson());
        
        // Don't auto-login after registration - user should login manually
        // await LocalStorageService.saveUser(user);

        return user;
    }

    // Login user locally
    static Future<User?> login(String username, String password) async {
        final usersBox = Hive.box('usersBox');
        final users = usersBox.values.toList();
        
        // Find user by username (name field) - safer retrieval using where
        final matchingUsers = users.where((u) {
            final userMap = u as Map;
            return userMap['name']?.toString().toLowerCase() == username.toLowerCase();
        }).toList();

        if (matchingUsers.isEmpty) {
            throw Exception('Invalid username or password');
        }

        final userData = matchingUsers.first as Map;
        final userMap = Map<String, dynamic>.from(userData);
        
        // In a real app, verify password hash here
        // For now, simple comparison
        final storedPassword = userMap['password']?.toString();
        if (storedPassword == null || storedPassword != password) {
            throw Exception('Invalid username or password');
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