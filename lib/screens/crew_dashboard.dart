import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/firebase_service.dart';
import '../models/task.dart' as app_task;
import '../models/user.dart';
import '../utils/responsive.dart';

class CrewDashboard extends StatefulWidget {
  const CrewDashboard({super.key});

  @override
  State<CrewDashboard> createState() => _CrewDashboardState();
}

class _CrewDashboardState extends State<CrewDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _aadhaarController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  int _currentStep = 0;
  double? _userLatitude;
  double? _userLongitude;
  double? _currentLatitude;
  double? _currentLongitude;
  bool _locationCaptured = false;
  bool _onboardingCompleted = false;
  List<app_task.Task> _assignedTasks = [];
  List<app_task.Task> _completedTasks = [];
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      setState(() {
        _onboardingCompleted =
            user.onboardingStatus == OnboardingStatus.verified;
        if (user.latitude != null && user.longitude != null) {
          _userLatitude = user.latitude;
          _userLongitude = user.longitude;
        }
      });

      if (_onboardingCompleted) {
        await _loadAssignedTasks();
      }
      await _getCurrentLocation();
    }
  }

  Future<void> _loadAssignedTasks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    
    if (currentUser != null) {
      try {
        final tasks = await FirebaseService().getTasksForUser(currentUser.id);
        final completedTasks = await FirebaseService().getCompletedTasksForUser(currentUser.id);
        setState(() {
          _assignedTasks = tasks.where((task) => task.status != app_task.TaskStatus.completed).toList();
          _completedTasks = completedTasks;
        });
      } catch (e) {
        print('Error loading tasks: $e');
      }
    }

  }

  Future<void> _acceptDuty(String taskId) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final success = await taskProvider.updateTaskStatus(
      taskId,
      app_task.TaskStatus.enRoute,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duty accepted! You can now proceed to the location.'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      await _loadAssignedTasks();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position =
          await html.window.navigator.geolocation.getCurrentPosition();
      final latitude = position.coords!.latitude!.toDouble();
      final longitude = position.coords!.longitude!.toDouble();

      setState(() {
        _currentLatitude = latitude;
        _currentLongitude = longitude;
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  bool _isWithinCheckInRange(app_task.Task task) {
    if (_currentLatitude == null ||
        _currentLongitude == null ||
        task.latitude == null ||
        task.longitude == null) {
      return false;
    }

    final distance = _calculateDistance(
      _currentLatitude!,
      _currentLongitude!,
      task.latitude!,
      task.longitude!,
    );

    return distance <= 1.0; // Within 1 kilometer
  }

  Future<void> _completeTask(String taskId) async {
    final remarks = _remarksController.text.trim();
    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter completion remarks')),
      );
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final success = await taskProvider.updateTaskStatus(
      taskId,
      app_task.TaskStatus.completed,
      completionRemarks: remarks,
    );

    if (success && mounted) {
      _remarksController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed successfully!'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      await _loadAssignedTasks();
    }
  }

  void _showTaskCompletionDialog(String taskId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Complete Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please enter completion remarks:'),
                const SizedBox(height: 16),
                TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter your remarks here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _completeTask(taskId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B2AA),
                ),
                child: const Text('Complete Task'),
              ),
            ],
          ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _submitOnboarding() async {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your Aadhaar card photo'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.currentUser?.id ?? '';

        String? photoUrl;
        if (_selectedFile != null && _selectedFile!.bytes != null) {
          photoUrl = await FirebaseService().uploadFile(
            _selectedFile!.bytes!,
            'aadhaar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }

        await FirebaseService().updateUserOnboardingData(
          userId,
          _aadhaarController.text,
          photoUrl,
        );

        setState(() {
          _currentStep = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ID verification submitted! Now capture your location.',
              ),
              backgroundColor: Color(0xFF20B2AA),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error submitting data: $e')));
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (_currentStep == 1) {
      await _captureLocation();
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position =
          await html.window.navigator.geolocation.getCurrentPosition();
      final latitude = position.coords!.latitude!.toDouble();
      final longitude = position.coords!.longitude!.toDouble();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      await taskProvider.updateUserLocation(userId, latitude, longitude);

      // Update onboarding status in Firebase first
      if (userId.isNotEmpty) {
        try {
          await FirebaseService().updateUserOnboardingStatus(
            userId,
            OnboardingStatus.verified,
          );
        } catch (e) {
          print('Error updating onboarding status: $e');
        }
      }

      setState(() {
        _userLatitude = latitude;
        _userLongitude = longitude;
        _locationCaptured = true;
        _onboardingCompleted = true;
      });

      await _loadAssignedTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured! Onboarding completed.'),
            backgroundColor: Color(0xFF20B2AA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing location: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkInToTask(String taskId) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final success = await taskProvider.updateTaskStatus(
      taskId,
      app_task.TaskStatus.checkedIn,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked in successfully!'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      await _loadAssignedTasks();
    }
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF20B2AA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'VD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Crew Manager',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFF20B2AA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _onboardingCompleted ? _buildTasksView() : _buildOnboardingView(),
    );
  }

  Widget _buildOnboardingView() {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              ResponsiveHelper.isMobile(context)
                  ? MediaQuery.of(context).size.width * 0.95
                  : 600,
        ),
        margin: ResponsiveHelper.getResponsiveMargin(context),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveHelper.getResponsiveCardPadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Crew Onboarding',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_currentStep == 0) _buildStep1(),
                if (_currentStep == 1) _buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Verify Your ID',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aadhaar ID Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aadhaarController,
                decoration: InputDecoration(
                  hintText: 'xxxx-xxxx-xxxx',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Aadhaar number';
                  }
                  if (value.length < 12) {
                    return 'Please enter a valid Aadhaar number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Aadhaar Card Photo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _selectedFile != null
                      ? 'File selected: ${_selectedFile!.name}'
                      : 'Upload Aadhaar Card Photo',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_aadhaarController.text.isNotEmpty &&
                              _selectedFile != null &&
                              !_isLoading)
                          ? _submitOnboarding
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B2AA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Capture Your Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        const Text(
          'We need your location to assign nearby tasks to you.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_locationCaptured) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Captured Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Lat: ${_userLatitude?.toStringAsFixed(6)}, Lng: ${_userLongitude?.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !_isLoading ? _submitOnboarding : null,
              icon: const Icon(Icons.location_on),
              label: const Text('Capture My Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B2AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF20B2AA)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTasksView() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(
            ResponsiveHelper.getResponsivePadding(context),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: ResponsiveHelper.isMobile(context) ? 16 : 24,
                    ),
                    child: Text(
                      'Welcome, ${Provider.of<AuthProvider>(context).currentUser?.name ?? 'Crew Member'}!',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          24,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Your Registered Location Section
                  _buildLocationSection(),
                  SizedBox(
                    height: ResponsiveHelper.isMobile(context) ? 24 : 32,
                  ),

                  // Today's Duty Assignment Section
                  _buildDutyAssignmentSection(),
                  SizedBox(height: ResponsiveHelper.isMobile(context) ? 24 : 32),
                  
                  // Completed Tasks History Section
                  _buildCompletedTasksSection(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        ResponsiveHelper.getResponsiveCardPadding(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Registered Location',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_userLatitude != null && _userLongitude != null) ...[
            Text(
              '${_userLatitude!.toStringAsFixed(6)}, ${_userLongitude!.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ] else ...[
            const Text(
              'Location not available',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
          SizedBox(height: ResponsiveHelper.isMobile(context) ? 16 : 20),
          Row(
            children: [
              Text(
                'Your Current Location',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _getCurrentLocation,
                child: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Color(0xFF20B2AA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentLatitude != null && _currentLongitude != null) ...[
            Text(
              '${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Text(
                  'Tap refresh to get current location',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                if (_currentLatitude == null)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDutyAssignmentSection() {
    if (_assignedTasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Duty Assignment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 12),
                  Text(
                    'No duty assigned for today',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final task = _assignedTasks.first;
    final distance =
        (_userLatitude != null &&
                _userLongitude != null &&
                task.latitude != null &&
                task.longitude != null)
            ? _calculateDistance(
              _userLatitude!,
              _userLongitude!,
              task.latitude!,
              task.longitude!,
            )
            : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        ResponsiveHelper.getResponsiveCardPadding(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Duty Assignment',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Notification-style assignment card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF20B2AA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF20B2AA).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B2AA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.locationName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'On-Site Check-In Point',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(task.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Distance and coordinates
                Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${distance.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (task.latitude != null && task.longitude != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '${task.latitude!.toStringAsFixed(6)}, ${task.longitude!.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                if (task.status == app_task.TaskStatus.assigned) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptDuty(task.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20B2AA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Accept Duty',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isWithinCheckInRange(task)
                                  ? () => _checkInToTask(task.id)
                                  : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                _isWithinCheckInRange(task)
                                    ? const Color(0xFF20B2AA)
                                    : Colors.grey,
                            side: BorderSide(
                              color:
                                  _isWithinCheckInRange(task)
                                      ? const Color(0xFF20B2AA)
                                      : Colors.grey,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isWithinCheckInRange(task)
                                ? 'Check In'
                                : 'Too Far (${distance.toStringAsFixed(1)}km)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (task.status == app_task.TaskStatus.enRoute) ...[
                  Container(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _isWithinCheckInRange(task)
                              ? () => _checkInToTask(task.id)
                              : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _isWithinCheckInRange(task)
                                ? const Color(0xFF20B2AA)
                                : Colors.grey,
                        side: BorderSide(
                          color:
                              _isWithinCheckInRange(task)
                                  ? const Color(0xFF20B2AA)
                                  : Colors.grey,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isWithinCheckInRange(task)
                            ? 'Check In Now'
                            : 'Get Closer to Check In (${distance.toStringAsFixed(1)}km away)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ] else if (task.status == app_task.TaskStatus.checkedIn) ...[
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checked In - Duty in Progress',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showTaskCompletionDialog(task.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Complete Task',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (task.status == app_task.TaskStatus.completed) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Duty Completed',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (task.completionRemarks != null &&
                          task.completionRemarks!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completion Remarks:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.completionRemarks!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(app_task.TaskStatus status) {
    switch (status) {
      case app_task.TaskStatus.assigned:
        return Colors.orange;
      case app_task.TaskStatus.enRoute:
        return Colors.blue;
      case app_task.TaskStatus.checkedIn:
        return Colors.green;
      case app_task.TaskStatus.completed:
        return Colors.blue.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(app_task.TaskStatus status) {
    switch (status) {
      case app_task.TaskStatus.assigned:
        return 'Assigned';
      case app_task.TaskStatus.enRoute:
        return 'En Route';
      case app_task.TaskStatus.checkedIn:
        return 'Checked In';
      case app_task.TaskStatus.completed:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Widget _buildCompletedTasksSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveCardPadding(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed Tasks History',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_completedTasks.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history, color: Colors.grey),
                  SizedBox(width: 12),
                  Text(
                    'No completed tasks yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _completedTasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = _completedTasks[index];
                return _buildCompletedTaskCard(task);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedTaskCard(app_task.Task task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.locationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed on ${task.updatedAt.day}/${task.updatedAt.month}/${task.updatedAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (task.completionRemarks != null && task.completionRemarks!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completion Notes:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.completionRemarks!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
