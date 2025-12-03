import 'package:hive/hive.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class AuthService {
    // Register user locally
    static Future<User> register(String username, String password) async {
        try {
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
            
            // Ensure usersBox is open
            Box usersBox;
            if (!Hive.isBoxOpen('usersBox')) {
                try {
                    usersBox = await Hive.openBox('usersBox');
                    print('Opened usersBox for registration');
                } catch (e) {
                    print('Error opening usersBox: $e');
                    throw Exception('User database is not available. Please restart the app.');
                }
            } else {
                usersBox = Hive.box('usersBox');
            }
        
        // Check if user already exists
        
            // Get all users to check for duplicate username - optimized with early exit
            try {
        final existingUsers = usersBox.values.toList();
                final normalizedUsername = username.trim().toLowerCase();
                
                for (final u in existingUsers) {
            try {
                        if (u == null) continue;
                        final userMap = u is Map ? Map<String, dynamic>.from(u) : null;
                        if (userMap == null) continue;
                        final name = userMap['name']?.toString().toLowerCase();
                        if (name == normalizedUsername) {
                            throw Exception('Username already exists. Please choose a different username or reset the app data.');
                        }
                    } catch (e) {
                        if (e.toString().contains('Username already exists')) {
                            rethrow;
                        }
                        // If data is corrupted, skip it
                        continue;
                    }
                }
            } catch (e) {
                if (e.toString().contains('Username already exists')) {
                    rethrow;
                }
                print('Error checking existing users: $e');
                // Continue with registration if check fails
        }

        // Create new user (using username as name, and empty email)
        final user = User(
            id: Uuid().v4(),
                name: username.trim(),
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
        } catch (e) {
            print('Registration error: $e');
            rethrow;
        }
    }

    // Login user locally
    static Future<User?> login(String username, String password) async {
        try {
        // Validate input
        if (username.trim().isEmpty) {
            throw Exception('Please enter your username');
        }
        if (password.isEmpty) {
            throw Exception('Please enter your password');
        }
        
            // Ensure usersBox is open
            Box usersBox;
            if (!Hive.isBoxOpen('usersBox')) {
                try {
                    usersBox = await Hive.openBox('usersBox');
                    print('Opened usersBox for login');
                } catch (e) {
                    print('Error opening usersBox: $e');
                    throw Exception('User database is not available. Please restart the app.');
                }
            } else {
                usersBox = Hive.box('usersBox');
            }
            
        final users = usersBox.values.toList();
            final normalizedUsername = username.trim().toLowerCase();
        
            // Find user by username (name field) - optimized with early exit
            Map<String, dynamic>? userData;
            for (final u in users) {
            try {
                    if (u == null) continue;
                final userMap = u is Map ? Map<String, dynamic>.from(u) : null;
                    if (userMap == null) continue;
                final name = userMap['name']?.toString();
                    if (name == null || name.isEmpty) continue;
                    if (name.toLowerCase().trim() == normalizedUsername) {
                        userData = userMap;
                        break; // Early exit when found
                    }
            } catch (e) {
                // If data is corrupted, skip it
                print('Error checking user: $e');
                    continue;
            }
            }

            if (userData == null) {
                throw Exception('Username not found. Please check your username or register a new account.');
            }
            
            // Validate required fields
            final storedName = userData['name']?.toString();
            final storedPassword = userData['password']?.toString();
            
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

            final user = User.fromJson(userData);
            await LocalStorageService.saveUser(user);
            return user;
        } catch (e) {
            final errorMsg = e.toString();
            if (errorMsg.contains('Incorrect password') || 
                errorMsg.contains('Username not found')) {
                rethrow; // Re-throw authentication errors as-is
            }
            print('Login error: $e');
            throw Exception('Error reading user data. Please try resetting the app data from Settings.');
        }
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