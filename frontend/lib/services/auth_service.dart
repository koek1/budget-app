import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
    static Future<void> saveUserData(Map<String, dynamic> userData) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', userData['token']);
        await prefs.setString('userId', userData['_id']);
        await prefs.setString('name', userData['name']);
        await prefs.setString('email', userData['email']);
    }

    static Future<void> logout() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('userId');
        await prefs.remove('name');
        await prefs.remove('email');
    }

    static Future <bool> islOggedIn() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs,getString('userId') != null;
    }

    static Future <String?> getUserId() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('userId');
    }
}