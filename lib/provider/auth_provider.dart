import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  User? _user;

  String? get accessToken => _accessToken;
  User? get user => _user;
  bool get isAuthenticated => _user != null && _accessToken != null;

  String baseUrl = 'http://192.168.1.101:8000';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance().catchError((e) {
        print('Error accessing SharedPreferences: $e');
        return null;
      });

      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      final username = prefs.getString('username');
      final email = prefs.getString('email');
      final role = prefs.getString('role');

      print('Initializing AuthProvider...');
      print('Access Token: $_accessToken');
      print('Refresh Token: $_refreshToken');
      print('Username: $username, Email: $email, Role: $role');

      // if (username != null && _accessToken != null) {
      //   _user = User(username: username, email: email, role: role ?? 'guest');
      //   print('User loaded from SharedPreferences: ${_user!.username}');
      // } else {
      //   print('No user data found in SharedPreferences. User will be null.');
      // }

      if (_refreshToken != null &&
          (_accessToken == null || _accessToken!.isEmpty)) {
        try {
          await refreshToken();
        } catch (e) {
          print('Failed to refresh token during init: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error initializing AuthProvider: $e');
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, bool rememberMe) async {
    print('Sending login request to $baseUrl/login/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('Login request timed out'));
      print(
          'Login response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('Error: Login response body is empty');
          return false;
        }
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        _refreshToken = data['refresh'];
        _user = User(
            username: username,
            email: data['user']['email'] ?? '',
            role: data['user']['role'] ?? 'student');
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('access_token', _accessToken!);
          await prefs.setString('refresh_token', _refreshToken!);
          await prefs.setString('username', _user!.username);
          await prefs.setString('email', _user!.email ?? '');
          await prefs.setString('role', _user!.role);
        }
        notifyListeners();
        return true;
      } else {
        print(
            'Error: Login failed with status ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    print('Sending register request to $baseUrl/register/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'username': username, 'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('Register request timed out'));
      print(
          'Register response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 201) {
        if (response.body.isEmpty) {
          print('Error: Register response body is empty');
          return false;
        }
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        _refreshToken = data['refresh'];
        _user = User.fromJson(data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('username', _user!.username);
        await prefs.setString('email', _user!.email ?? '');
        await prefs.setString('role', _user!.role);
        notifyListeners();
        return true;
      } else {
        print(
            'Error: Registration failed with status ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    print('Sending forgot password request to $baseUrl/send-reset-email/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/send-reset-email/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('Forgot password request timed out'));
      print(
          'Forgot password response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'Error: Forgot password failed with status ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during forgot password: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String uid, String token, String password) async {
    print(
        'Sending reset password request to $baseUrl/reset-password/$uid/$token/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password/$uid/$token/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('Reset password request timed out'));
      print(
          'Reset password response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'Error: Reset password failed with status ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during reset password: $e');
      return false;
    }
  }

  Future<bool> sendReturnEmail(String email, String returnPage) async {
    print('Sending return email request to $baseUrl/send-return-email/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/send-return-email/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'return_page': returnPage}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException(
                  'Send return email request timed out'));
      print(
          'Send return email response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'Error: Send return email failed with status ${response.statusCode}, body=${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during send return email: $e');
      return false;
    }
  }

  Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString('refresh_token');
    if (_refreshToken == null) {
      print('Error: No refresh token available');
      return false;
    }

    print('Refreshing token at $baseUrl/api/token/refresh/');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/token/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': _refreshToken}),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('Token refresh request timed out'));
      print(
          'Refresh token response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        await prefs.setString('access_token', _accessToken!);
        notifyListeners();
        return true;
      } else {
        print(
            'Failed to refresh token. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('username');
      await prefs.remove('email');
      await prefs.remove('role');
      _accessToken = null;
      _refreshToken = null;
      _user = null;
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}

class User {
  final String username;
  final String? email;
  final String role;

  User({required this.username, this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'student',
    );
  }
}
