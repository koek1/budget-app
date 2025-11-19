import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator localhost
  
  // Get auth token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  // Headers with auth
  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  // Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      body: json.encode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }
  
  // Register
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      body: json.encode({'name': name, 'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }
  
  // Get transactions
  static Future<List<dynamic>> getTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions'),
      headers: await getHeaders(),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load transactions');
    }
  }
  
  // Add transaction
  static Future<dynamic> addTransaction(Map<String, dynamic> transaction) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      body: json.encode(transaction),
      headers: await getHeaders(),
    );
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add transaction');
    }
  }
}