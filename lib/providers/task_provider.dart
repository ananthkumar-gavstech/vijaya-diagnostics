import 'package:flutter/material.dart';
import '../models/task.dart' as app_task;
import '../models/user.dart';
import '../services/firebase_service.dart';

class TaskProvider extends ChangeNotifier {
  List<app_task.Task> _tasks = [];
  List<User> _crewMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<app_task.Task> get tasks => _tasks;
  List<User> get crewMembers => _crewMembers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final FirebaseService _firebaseService = FirebaseService();

  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _firebaseService.getTasks();
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCrewMembers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _crewMembers = await _firebaseService.getCrewMembers();
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> assignTask(String taskId, String userId, String userEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.assignTask(taskId, userId, userEmail);
      await loadTasks();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserAvailability(String userId, bool isAvailable) async {
    try {
      await _firebaseService.updateUserAvailability(userId, isAvailable);
      await loadCrewMembers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createTask(String locationName, double? latitude, double? longitude) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.createTask(locationName, latitude, longitude);
      await loadTasks();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCrewMember(String email, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.createCrewMember(email, name);
      await loadCrewMembers();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<app_task.Task>> getTasksForUser(String userId) async {
    try {
      return await _firebaseService.getTasksForUser(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<bool> updateTaskStatus(String taskId, app_task.TaskStatus status) async {
    try {
      await _firebaseService.updateTaskStatus(taskId, status);
      await loadTasks();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserLocation(String userId, double latitude, double longitude) async {
    try {
      await _firebaseService.updateUserLocation(userId, latitude, longitude);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
