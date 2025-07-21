import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/firebase_service.dart';
import '../models/onboarding_data.dart';
import '../models/task.dart' as app_task;

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
  bool _locationCaptured = false;
  bool _onboardingCompleted = false;
  List<app_task.Task> _assignedTasks = [];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null && user.latitude != null && user.longitude != null) {
      setState(() {
        _onboardingCompleted = true;
        _userLatitude = user.latitude;
        _userLongitude = user.longitude;
      });
      await _loadAssignedTasks();
    }
  }

  Future<void> _loadAssignedTasks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id ?? '';
    
    final tasks = await taskProvider.getTasksForUser(userId);
    setState(() {
      _assignedTasks = tasks;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _submitOnboarding() async {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your Aadhaar card photo')),
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

        final onboardingData = OnboardingData(
          userId: userId,
          aadhaarNumber: _aadhaarController.text,
          aadhaarPhotoUrl: photoUrl,
          status: OnboardingStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await FirebaseService().saveOnboardingData(onboardingData);

        setState(() {
          _currentStep = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID verification submitted! Now capture your location.'),
              backgroundColor: Color(0xFF20B2AA),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting data: $e')),
          );
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
      final position = await html.window.navigator.geolocation.getCurrentPosition();
      final latitude = position.coords!.latitude!.toDouble();
      final longitude = position.coords!.longitude!.toDouble();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      await taskProvider.updateUserLocation(userId, latitude, longitude);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing location: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkInToTask(String taskId) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    final success = await taskProvider.updateTaskStatus(taskId, app_task.TaskStatus.checkedIn);
    
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
                  'Vijay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Crew Manager',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      authProvider.currentUser?.email ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFF20B2AA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Crew Onboarding',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aadhaar ID Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                  onPressed: (_aadhaarController.text.isNotEmpty && 
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
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'We need your location to assign nearby tasks to you.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
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
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Assigned Tasks',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_assignedTasks.isEmpty) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks assigned yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: _assignedTasks.length,
                    itemBuilder: (context, index) {
                      final task = _assignedTasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(app_task.Task task) {
    final canCheckIn = task.status == app_task.TaskStatus.assigned;
    final isCheckedIn = task.status == app_task.TaskStatus.checkedIn;
    final isCompleted = task.status == app_task.TaskStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.locationName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(task.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (task.latitude != null && task.longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'Location: ${task.latitude!.toStringAsFixed(6)}, ${task.longitude!.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (canCheckIn) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _checkInToTask(task.id),
                  icon: const Icon(Icons.location_on),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B2AA),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else if (isCheckedIn) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Checked In',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
}
