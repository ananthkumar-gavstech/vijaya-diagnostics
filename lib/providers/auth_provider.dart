import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.userType == UserType.admin;
  bool get isCrewMember => _currentUser?.userType == UserType.crewMember;

  final FirebaseService _firebaseService = FirebaseService();

  Future<bool> signIn(String email, String password, UserType userType) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _firebaseService.signInWithEmailAndPassword(
        email,
        password,
        userType,
      );

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.signOut();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
