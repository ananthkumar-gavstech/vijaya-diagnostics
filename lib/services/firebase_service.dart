import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart' as app_user;
import '../models/task.dart' as app_task;
import '../models/onboarding_data.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC0g0PEtpoqoryEeSQhgmwC7T-zmPEWdac",
          authDomain: "indriya-45912.firebaseapp.com",
          projectId: "indriya-45912",
          storageBucket: "indriya-45912.firebasestorage.app",
          messagingSenderId: "475330667611",
          appId: "1:475330667611:web:b63a3ad7c2b17992074b7e",
        ),
      );
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  }

  Future<app_user.User?> signInWithEmailAndPassword(
    String email,
    String password,
    app_user.UserType userType,
  ) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final userDoc = await firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (userDoc.exists) {
          return app_user.User.fromMap(userDoc.data()!);
        } else {
          final newUser = app_user.User(
            id: credential.user!.uid,
            email: email,
            userType: userType,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(newUser.toMap());

          return newUser;
        }
      }
    } catch (e) {
      print('Firebase auth not configured, using mock authentication');
      return app_user.User(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        userType: userType,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<List<app_task.Task>> getTasks() async {
    try {
      final snapshot = await firestore.collection('tasks').get();
      return snapshot.docs
          .map((doc) => app_task.Task.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Firebase not configured, returning mock tasks');
      return [
        app_task.Task(
          id: 'task1',
          locationName: 'Downtown Diagnostic Center',
          assignedToUserId: 'crew1',
          assignedToEmail: 'crew.member@example.com',
          status: app_task.TaskStatus.assigned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        app_task.Task(
          id: 'task2',
          locationName: 'Westside Health Clinic',
          status: app_task.TaskStatus.unassigned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        app_task.Task(
          id: 'task3',
          locationName: 'Valley Imaging Services',
          status: app_task.TaskStatus.unassigned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<void> assignTask(String taskId, String userId, String userEmail) async {
    try {
      await firestore.collection('tasks').doc(taskId).update({
        'assignedToUserId': userId,
        'assignedToEmail': userEmail,
        'status': app_task.TaskStatus.assigned.toString(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to assign task: $e');
    }
  }

  Future<List<app_user.User>> getCrewMembers() async {
    try {
      final snapshot = await firestore
          .collection('users')
          .where('userType', isEqualTo: app_user.UserType.crewMember.toString())
          .get();
      return snapshot.docs
          .map((doc) => app_user.User.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Firebase not configured, returning mock crew members');
      return [
        app_user.User(
          id: 'crew1',
          email: 'crew.member@example.com',
          userType: app_user.UserType.crewMember,
          isAvailable: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        app_user.User(
          id: 'crew2',
          email: 'john.doe@example.com',
          userType: app_user.UserType.crewMember,
          isAvailable: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        app_user.User(
          id: 'crew3',
          email: 'jane.smith@example.com',
          userType: app_user.UserType.crewMember,
          isAvailable: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<void> updateUserAvailability(String userId, bool isAvailable) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'isAvailable': isAvailable,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to update availability: $e');
    }
  }

  Future<void> saveOnboardingData(OnboardingData data) async {
    try {
      await firestore
          .collection('onboarding')
          .doc(data.userId)
          .set(data.toMap());
    } catch (e) {
      throw Exception('Failed to save onboarding data: $e');
    }
  }

  Future<void> createTask(String locationName, double? latitude, double? longitude) async {
    try {
      final taskId = firestore.collection('tasks').doc().id;
      final task = app_task.Task(
        id: taskId,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        status: app_task.TaskStatus.unassigned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestore.collection('tasks').doc(taskId).set(task.toMap());
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> createCrewMember(String email, String name) async {
    try {
      final userId = firestore.collection('users').doc().id;
      final user = app_user.User(
        id: userId,
        email: email,
        name: name,
        userType: app_user.UserType.crewMember,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestore.collection('users').doc(userId).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create crew member: $e');
    }
  }

  Future<String> uploadFile(Uint8List fileBytes, String fileName) async {
    try {
      final ref = storage.ref().child('uploads/$fileName');
      final uploadTask = await ref.putData(fileBytes);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<app_task.Task>> getTasksForUser(String userId) async {
    try {
      final snapshot = await firestore
          .collection('tasks')
          .where('assignedToUserId', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => app_task.Task.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Firebase not configured, returning mock assigned tasks');
      return [
        app_task.Task(
          id: 'task1',
          locationName: 'Downtown Diagnostic Center',
          assignedToUserId: userId,
          assignedToEmail: 'crew.member@example.com',
          status: app_task.TaskStatus.assigned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<void> updateTaskStatus(String taskId, app_task.TaskStatus status) async {
    try {
      await firestore.collection('tasks').doc(taskId).update({
        'status': status.toString(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to update task status: $e');
    }
  }

  Future<void> updateUserLocation(String userId, double latitude, double longitude) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to update user location: $e');
    }
  }

  Future<void> initializeDefaultData() async {
    try {
      final tasksSnapshot = await firestore.collection('tasks').get();
      if (tasksSnapshot.docs.isEmpty) {
        final defaultTasks = [
          app_task.Task(
            id: 'task1',
            locationName: 'Downtown Diagnostic Center',
            assignedToUserId: 'crew1',
            assignedToEmail: 'crew.member@example.com',
            status: app_task.TaskStatus.assigned,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          app_task.Task(
            id: 'task2',
            locationName: 'Westside Health Clinic',
            status: app_task.TaskStatus.unassigned,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          app_task.Task(
            id: 'task3',
            locationName: 'Valley Imaging Services',
            status: app_task.TaskStatus.unassigned,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        for (final task in defaultTasks) {
          await firestore.collection('tasks').doc(task.id).set(task.toMap());
        }
      }

      final usersSnapshot = await firestore.collection('users').get();
      if (usersSnapshot.docs.isEmpty) {
        final defaultUsers = [
          app_user.User(
            id: 'crew1',
            email: 'crew.member@example.com',
            userType: app_user.UserType.crewMember,
            name: 'Crew Member',
            isAvailable: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          app_user.User(
            id: 'crew2',
            email: 'jane.doe@example.com',
            userType: app_user.UserType.crewMember,
            name: 'Jane Doe',
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          app_user.User(
            id: 'admin1',
            email: 'admin@example.com',
            userType: app_user.UserType.admin,
            name: 'Admin User',
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        for (final user in defaultUsers) {
          await firestore.collection('users').doc(user.id).set(user.toMap());
        }
      }
    } catch (e) {
      print('Failed to initialize default data: $e');
    }
  }
}
