import 'package:hive/hive.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class AuthService {
    // Register user locally
    static Future<User> register(String username, String password) async {
        // Validate input
        if (username.trim().isEmpty) {
            throw Exception('Username cannot be empty');
        }
        if (password.isEmpty) {
            throw Exception('Password cannot be empty');
        }
        if (password.length < 4) {
            throw Exception('Password must be at least 4 characters');
        }
        
        // Check if user already exists
        final usersBox = Hive.box('usersBox');
        
        // Get all users to check for duplicate username
        final existingUsers = usersBox.values.toList();
        final userExists = existingUsers.any((u) {
            try {
                final userMap = u as Map;
                return userMap['name']?.toString().toLowerCase() == username.trim().toLowerCase();
            } catch (e) {
                // If data is corrupted, skip it
                return false;
            }
        });
        
        if (userExists) {
            throw Exception('Username already exists. Please choose a different username or reset the app data.');
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
        // Validate input
        if (username.trim().isEmpty) {
            throw Exception('Please enter your username');
        }
        if (password.isEmpty) {
            throw Exception('Please enter your password');
        }
        
        final usersBox = Hive.box('usersBox');
        final users = usersBox.values.toList();
        
        // Find user by username (name field) - safer retrieval using where
        final matchingUsers = users.where((u) {
            try {
                if (u == null) return false;
                final userMap = u is Map ? Map<String, dynamic>.from(u) : null;
                if (userMap == null) return false;
                final name = userMap['name']?.toString();
                if (name == null || name.isEmpty) return false;
                return name.toLowerCase().trim() == username.trim().toLowerCase();
            } catch (e) {
                // If data is corrupted, skip it
                print('Error checking user: $e');
                return false;
            }
        }).toList();

        if (matchingUsers.isEmpty) {
            throw Exception('Username not found. Please check your username or register a new account.');
        }

        User? user;
        try {
            final userData = matchingUsers.first;
            if (userData == null) {
                throw Exception('User data is null');
            }
            
            final userMap = userData is Map 
                ? Map<String, dynamic>.from(userData) 
                : throw Exception('Invalid user data format');
            
            // Validate required fields
            final storedName = userMap['name']?.toString();
            final storedPassword = userMap['password']?.toString();
            
            if (storedName == null || storedName.isEmpty) {
                throw Exception('User data is missing username');
            }
            
            if (storedPassword == null || storedPassword.isEmpty) {
                throw Exception('User data is missing password');
            }
            
            // In a real app, verify password hash here
            // For now, simple comparison - ensure exact match
            if (storedPassword != password) {
                throw Exception('Incorrect password. Please try again.');
            }

            user = User.fromJson(userMap);
            await LocalStorageService.saveUser(user);
        } catch (e) {
            final errorMsg = e.toString();
            if (errorMsg.contains('Incorrect password')) {
                rethrow;
            }
            print('Login error: $e');
            throw Exception('Error reading user data. Please try resetting the app data from Settings.');
        }

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