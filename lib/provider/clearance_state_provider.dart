import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClearanceStateProvider with ChangeNotifier {
  List<ClearanceApplication> _applications = [];
  List<ClearanceFeedback> _feedbacks = [];
  bool _hasSubmittedApplication = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _userId;

  List<ClearanceApplication> get applications => _applications;
  List<ClearanceFeedback> get feedbacks => _feedbacks;
  bool get hasSubmittedApplication => _hasSubmittedApplication;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  final String baseUrl = 'http://192.168.1.101:8000';
  final Box _hiveBox = Hive.box('clearance_data');
  static const String dataVersion = '1.0';

  Future<void> initialize(String? userId, String? accessToken) async {
    if (userId == null || userId == _userId) return;
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCachedData();
      if (accessToken != null) {
        await _syncWithBackend(accessToken);
      }
    } catch (e) {
      print('Error initializing ClearanceStateProvider: $e');
      _hasError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'clearance_data_$_userId';
      final cachedData = _hiveBox.get(cacheKey);

      _hasSubmittedApplication =
          prefs.getBool('has_submitted_application_$_userId') ?? false;

      if (cachedData != null && cachedData['version'] == dataVersion) {
        _applications = (cachedData['applications'] as List)
            .map((json) => ClearanceApplication.fromJson(json))
            .toList();
        _feedbacks = (cachedData['feedbacks'] as List)
            .map((json) => ClearanceFeedback.fromJson(json))
            .toList();
        print(
            'Loaded cached data for user $_userId: ${_applications.length} applications, ${_feedbacks.length} feedbacks');
      } else {
        _applications = [];
        _feedbacks = [];
        print('No valid cached data found for user $_userId');
      }
      notifyListeners();
    } catch (e) {
      print('Error loading cached data: $e');
      _applications = [];
      _feedbacks = [];
      notifyListeners();
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'clearance_data_$_userId';
      await _hiveBox.put(cacheKey, {
        'version': dataVersion,
        'applications': _applications.map((app) => app.toJson()).toList(),
        'feedbacks': _feedbacks.map((fb) => fb.toJson()).toList(),
      });
      await prefs.setBool(
          'has_submitted_application_$_userId', _hasSubmittedApplication);
      print('Saved cached data for user $_userId');
    } catch (e) {
      print('Error saving cached data: $e');
    }
  }

  Future<void> _syncWithBackend(String accessToken) async {
    try {
      await _fetchDataWithRetry(() => _fetchApplications(accessToken));
      await _fetchDataWithRetry(() => _fetchFeedbacks(accessToken));
      await _saveCachedData();
    } catch (e) {
      print('Error syncing with backend: $e');
      _hasError = true;
      notifyListeners();
    }
  }

  Future<void> submitApplication(
      ClearanceApplication application, String accessToken) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/applications/'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(application.toJson()),
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException(
                  'Submit application request timed out'));

      if (response.statusCode == 201) {
        _applications.add(application);
        _hasSubmittedApplication = true;
        await _saveCachedData();
        await _syncWithBackend(accessToken);
        print('Application submitted successfully');
      } else if (response.statusCode == 401) {
        throw Exception('Token expired. Please log in again.');
      } else {
        throw Exception('Failed to submit application: ${response.body}');
      }
    } catch (e) {
      print('Error submitting application: $e');
      _hasError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchApplications(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/applications/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('Fetch applications request timed out'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applications = (data as List)
            .map((json) => ClearanceApplication.fromJson(json))
            .toList();
        _hasSubmittedApplication = _applications.isNotEmpty;
        print('Fetched ${_applications.length} applications');
      } else {
        throw Exception('Failed to fetch applications: ${response.body}');
      }
    } catch (e) {
      print('Error fetching applications: $e');
      throw e;
    }
  }

  Future<void> _fetchFeedbacks(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feedbacks/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('Fetch feedbacks request timed out'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _feedbacks = (data as List)
            .map((json) => ClearanceFeedback.fromJson(json))
            .toList();
        print('Fetched ${_feedbacks.length} feedbacks');
      } else {
        throw Exception('Failed to fetch feedbacks: ${response.body}');
      }
    } catch (e) {
      print('Error fetching feedbacks: $e');
      throw e;
    }
  }

  Future<void> _fetchDataWithRetry(
      Future<void> Function() fetchFunction) async {
    const maxRetries = 3;
    int retryCount = 0;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        await fetchFunction();
        success = true;
      } catch (e) {
        retryCount++;
        print('Retry $retryCount/$maxRetries failed: $e');
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
        } else {
          throw e;
        }
      }
    }
  }

  Future<void> clearData() async {
    if (_userId == null) return;
    try {
      final cacheKey = 'clearance_data_$_userId';
      await _hiveBox.delete(cacheKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_submitted_application_$_userId');
      _applications = [];
      _feedbacks = [];
      _hasSubmittedApplication = false;
      _userId = null;
      notifyListeners();
      print('Cleared clearance data');
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}

class ClearanceApplication {
  final String name;
  final String email;
  final String phoneNumber;
  final String sex;
  final String department;
  final String program;
  final String customProgram;
  final String level;
  final String reason;
  final String yearSemester;

  ClearanceApplication({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.sex,
    required this.department,
    required this.program,
    required this.customProgram,
    required this.level,
    required this.reason,
    required this.yearSemester,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'sex': sex,
      'department': department,
      'program': program,
      'custom_program': customProgram,
      'level': level,
      'reason': reason,
      'year_semester': yearSemester,
    };
  }

  factory ClearanceApplication.fromJson(Map<String, dynamic> json) {
    if (json['name'] == null ||
        json['email'] == null ||
        json['sex'] == null ||
        json['department'] == null ||
        json['program'] == null ||
        json['level'] == null ||
        json['reason'] == null ||
        json['year_semester'] == null) {
      throw FormatException(
          'Invalid application data: missing required fields');
    }
    return ClearanceApplication(
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phone_number'] ?? '',
      sex: json['sex'],
      department: json['department'],
      program: json['program'],
      customProgram: json['custom_program'] ?? '',
      level: json['level'],
      reason: json['reason'],
      yearSemester: json['year_semester'],
    );
  }
}

class ClearanceFeedback {
  final String regNo;
  final String property;
  final String status;
  final String name;
  final String department;
  final String sign;
  final String date;
  final String rejectionReason;

  ClearanceFeedback({
    required this.regNo,
    required this.property,
    required this.status,
    required this.name,
    required this.department,
    required this.sign,
    required this.date,
    required this.rejectionReason,
  });

  factory ClearanceFeedback.fromJson(Map<String, dynamic> json) {
    if (json['reg_no'] == null ||
        json['property'] == null ||
        json['status'] == null ||
        json['name'] == null ||
        json['department'] == null ||
        json['sign'] == null ||
        json['date'] == null) {
      throw FormatException('Invalid feedback data: missing required fields');
    }
    return ClearanceFeedback(
      regNo: json['reg_no'],
      property: json['property'],
      status: json['status'],
      name: json['name'],
      department: json['department'],
      sign: json['sign'],
      date: json['date'],
      rejectionReason: json['rejection_reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reg_no': regNo,
      'property': property,
      'status': status,
      'name': name,
      'department': department,
      'sign': sign,
      'date': date,
      'rejection_reason': rejectionReason,
    };
  }
}
