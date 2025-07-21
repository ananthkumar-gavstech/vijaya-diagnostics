import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../utils/responsive.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _selectedCrewMembers = {};

  final _taskFormKey = GlobalKey<FormState>();
  final _locationNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _showTaskForm = false;

  final _crewFormKey = GlobalKey<FormState>();
  final _crewEmailController = TextEditingController();
  final _crewNameController = TextEditingController();
  bool _showCrewForm = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _crewEmailController.dispose();
    _crewNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    await taskProvider.loadTasks();
    await taskProvider.loadCrewMembers();
    await taskProvider.updateCrewAvailability();
  }

  Future<void> _assignTask(String taskId) async {
    final selectedUserId = _selectedCrewMembers[taskId];
    if (selectedUserId == null) return;

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final crewMember = taskProvider.crewMembers.firstWhere(
      (member) => member.id == selectedUserId,
    );

    final success = await taskProvider.assignTask(
      taskId,
      selectedUserId,
      crewMember.email,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task assigned successfully!'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      setState(() {
        _selectedCrewMembers.remove(taskId);
      });
    }
  }

  Future<void> _createTask() async {
    if (!_taskFormKey.currentState!.validate()) return;

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final latitude =
        _latitudeController.text.isNotEmpty
            ? double.tryParse(_latitudeController.text)
            : null;
    final longitude =
        _longitudeController.text.isNotEmpty
            ? double.tryParse(_longitudeController.text)
            : null;

    final success = await taskProvider.createTask(
      _locationNameController.text,
      latitude,
      longitude,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created successfully!'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      _locationNameController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() => _showTaskForm = false);
    }
  }

  Future<void> _createCrewMember() async {
    if (!_crewFormKey.currentState!.validate()) return;

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final success = await taskProvider.createCrewMember(
      _crewEmailController.text,
      _crewNameController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crew member added successfully!'),
          backgroundColor: Color(0xFF20B2AA),
        ),
      );
      _crewEmailController.clear();
      _crewNameController.clear();
      setState(() => _showCrewForm = false);
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
      floatingActionButton:
          ResponsiveHelper.isMobile(context)
              ? _tabController.index == 0
                  ? ElevatedButton.icon(
                    onPressed:
                        () => setState(() => _showTaskForm = !_showTaskForm),
                    icon: Icon(_showTaskForm ? Icons.close : Icons.add),
                    label: Text(_showTaskForm ? 'Cancel' : 'Create New Task'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFF20B2AA),
                      foregroundColor: Colors.white,
                    ),
                  )
                  : ElevatedButton.icon(
                    onPressed:
                        () => setState(() => _showCrewForm = !_showCrewForm),
                    icon: Icon(_showCrewForm ? Icons.close : Icons.person_add),
                    label: Text(_showCrewForm ? 'Cancel' : 'Add Crew Member'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFF20B2AA),
                      foregroundColor: Colors.white,
                    ),
                  )
              : null,
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
            // Header Section
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
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(0);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _tabController.index == 0
                                        ? const Color(0xFF6C5CE7)
                                        : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                'All Tasks',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      _tabController.index == 0
                                          ? Colors.white
                                          : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(1);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _tabController.index == 1
                                        ? const Color(0xFF6C5CE7)
                                        : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Crew Availability',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      _tabController.index == 1
                                          ? Colors.white
                                          : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return IndexedStack(
                    index: _tabController.index,
                    children: [_buildTasksTab(), _buildAvailabilityTab()],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (taskProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${taskProvider.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.all(
            ResponsiveHelper.getResponsivePadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Duty Assignments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_showTaskForm) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _taskFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _locationNameController,
                            decoration: const InputDecoration(
                              labelText: 'Location Name',
                              border: OutlineInputBorder(),
                            ),
                            validator:
                                (value) =>
                                    value?.isEmpty == true
                                        ? 'Please enter location name'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latitudeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value?.isNotEmpty == true) {
                                      final lat = double.tryParse(value!);
                                      if (lat == null ||
                                          lat < -90 ||
                                          lat > 90) {
                                        return 'Invalid latitude (-90 to 90)';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _longitudeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value?.isNotEmpty == true) {
                                      final lng = double.tryParse(value!);
                                      if (lng == null ||
                                          lng < -180 ||
                                          lng > 180) {
                                        return 'Invalid longitude (-180 to 180)';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _createTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B2AA),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Create Task'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: taskProvider.tasks.length,
                  itemBuilder: (context, index) {
                    final task = taskProvider.tasks[index];
                    return _buildTaskCard(task, taskProvider.crewMembers);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return Colors.red;
      case TaskStatus.assigned:
        return const Color(0xFF20B2AA);
      case TaskStatus.enRoute:
        return Colors.orange;
      case TaskStatus.checkedIn:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
    }
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.unassigned:
        return 'Unassigned';
      case TaskStatus.assigned:
        return 'Assigned';
      case TaskStatus.enRoute:
        return 'En Route';
      case TaskStatus.checkedIn:
        return 'Checked In';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  Widget _buildTaskCard(Task task, List<User> crewMembers) {
    final isUnassigned = task.status == TaskStatus.unassigned;
    final isCompleted = task.status == TaskStatus.completed;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Card(
        color: Colors.white,
        margin: EdgeInsets.only(
          bottom: ResponsiveHelper.isMobile(context) ? 12 : 16,
        ),
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveHelper.getResponsiveCardPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveHelper.isMobile(context)
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              task.locationName,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(
                                  context,
                                  16,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(task.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _getStatusText(task.status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.locationName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              16,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

              if (task.latitude != null && task.longitude != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${task.latitude!.toStringAsFixed(6)}, ${task.longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              if (task.assignedToEmail != null) ...[
                Row(
                  children: [
                    const Text('Assigned to: '),
                    Text(
                      task.assignedToEmail!,
                      style: const TextStyle(
                        color: Color(0xFF20B2AA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                if (isCompleted && task.completionRemarks != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completion Remarks:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.completionRemarks!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    const Text('Assigned to: '),
                    const Text(
                      'Unassigned',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              if (isUnassigned) ...[
                SizedBox(height: ResponsiveHelper.isMobile(context) ? 8 : 12),
                ResponsiveHelper.isMobile(context)
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 40,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCrewMembers[task.id],
                            hint: const Text(
                              'Select Crew...',
                              style: TextStyle(fontSize: 14),
                            ),
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              isDense: true,
                            ),
                            items:
                                crewMembers
                                    .where((member) => member.isAvailable)
                                    .map(
                                      (member) => DropdownMenuItem(
                                        value: member.id,
                                        child: Text(
                                          member.email,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCrewMembers[task.id] = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed:
                                _selectedCrewMembers[task.id] != null
                                    ? () => _assignTask(task.id)
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B2AA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Assign',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCrewMembers[task.id],
                              hint: const Text(
                                'Select Crew...',
                                style: TextStyle(fontSize: 14),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                isDense: true,
                              ),
                              items:
                                  crewMembers
                                      .where((member) => member.isAvailable)
                                      .map(
                                        (member) => DropdownMenuItem(
                                          value: member.id,
                                          child: Text(
                                            member.email,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCrewMembers[task.id] = value!;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed:
                                _selectedCrewMembers[task.id] != null
                                    ? () => _assignTask(task.id)
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B2AA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text(
                              'Assign',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityTab() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (taskProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${taskProvider.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.all(
            ResponsiveHelper.getResponsivePadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Crew Availability Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_showCrewForm) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _crewFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _crewEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value?.isEmpty == true)
                                return 'Please enter email';
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value!)) {
                                return 'Please enter valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _crewNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                            ),
                            validator:
                                (value) =>
                                    value?.isEmpty == true
                                        ? 'Please enter name'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _createCrewMember,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B2AA),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add Crew Member'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: taskProvider.crewMembers.length,
                  itemBuilder: (context, index) {
                    final member = taskProvider.crewMembers[index];
                    return _buildAvailabilityCard(member);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityCard(User member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (member.latitude != null &&
                          member.longitude != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Location: ${member.latitude!.toStringAsFixed(6)}, ${member.longitude!.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        member.isAvailable
                            ? const Color(0xFF20B2AA)
                            : const Color(0xFFDC3545),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.isAvailable ? 'Available' : 'Unavailable',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
