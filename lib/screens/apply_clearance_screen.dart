import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../provider/clearance_state_provider.dart';
import 'clearance_feedback_screen.dart';

class ApplyClearanceScreen extends StatefulWidget {
  const ApplyClearanceScreen({super.key});

  @override
  _ApplyClearanceScreenState createState() => _ApplyClearanceScreenState();
}

class _ApplyClearanceScreenState extends State<ApplyClearanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otherProgramController = TextEditingController();

  String _sex = 'Male';
  String _department = 'Logistics and Transport Management (LTM)';
  String _program = "Bachelor's Degree in Logistics and Transport Management";
  String _level = '4';
  String _reason = 'Complete Studies';
  String? _yearSemester;

  @override
  void initState() {
    super.initState();
    _yearSemester = _generateSemesters().last;
    final programOptions = ['Other', ...PROGRAM_CHOICES.map((e) => e)];
    if (!programOptions.contains(_program)) {
      _program = programOptions.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otherProgramController.dispose();
    super.dispose();
  }

  List<String> _generateSemesters() {
    final now = DateTime.now();
    final currentYear = now.month >= 7 ? now.year : now.year - 1;
    final semesters = <String>[];
    for (int year = currentYear - 10; year <= currentYear; year++) {
      final academicYear = '$year/${(year + 1).toString().substring(2)}';
      semesters.add('$academicYear - Semester I');
      semesters.add('$academicYear - Semester II');
    }
    return semesters;
  }

  void _updateState(String? value, String field) {
    if (value == null) return;
    setState(() {
      switch (field) {
        case 'sex':
          _sex = value;
          break;
        case 'department':
          _department = value;
          break;
        case 'program':
          _program = value;
          if (value != 'Other') _otherProgramController.clear();
          break;
        case 'level':
          _level = value;
          break;
        case 'reason':
          _reason = value;
          break;
        case 'yearSemester':
          _yearSemester = value;
          break;
      }
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clearanceProvider =
          Provider.of<ClearanceStateProvider>(context, listen: false);

      try {
        final application = ClearanceApplication(
          name: _nameController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          sex: _sex,
          department: _department,
          program: _program == 'Other' ? 'Other' : _program,
          customProgram:
              _program == 'Other' ? _otherProgramController.text : '',
          level: _level,
          reason: _reason,
          yearSemester: _yearSemester!,
        );

        await clearanceProvider.submitApplication(
            application, authProvider.accessToken!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const ClearanceFeedbackScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clearanceProvider = Provider.of<ClearanceStateProvider>(context);
    final isAuthenticated = authProvider.user != null;
    final hasSubmittedApplication = clearanceProvider.hasSubmittedApplication;
    final isOtherSelected = _program == 'Other';

    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Apply for Clearance'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: const Center(
          child: Text(
            'Please log in to apply for clearance.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Clearance'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasSubmittedApplication)
                Container(
                  color: Colors.orange[100],
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You have already submitted a clearance application.',
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ClearanceFeedbackScreen()),
                          );
                        },
                        child: const Text('View Feedback'),
                      ),
                    ],
                  ),
                ),
              if (!hasSubmittedApplication) ...[
                const Text(
                  'Clearance Application',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextFormField(
                            'Name *',
                            controller: _nameController,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Name is required'
                                    : null,
                          ),
                          _buildTextFormField(
                            'Email *',
                            controller: _emailController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            'Phone Number *',
                            controller: _phoneController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Phone number is required';
                              }
                              if (!RegExp(r'^\+?[0-9]{10,15}$')
                                  .hasMatch(value)) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Sex *',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              Radio<String>(
                                value: 'Male',
                                groupValue: _sex,
                                onChanged: (value) =>
                                    _updateState(value, 'sex'),
                                activeColor: Colors.indigo,
                              ),
                              const Text('Male'),
                              const SizedBox(width: 16),
                              Radio<String>(
                                value: 'Female',
                                groupValue: _sex,
                                onChanged: (value) =>
                                    _updateState(value, 'sex'),
                                activeColor: Colors.indigo,
                              ),
                              const Text('Female'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Academic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            'Department *',
                            _department,
                            DEPARTMENT_CHOICES,
                            (value) => _updateState(value, 'department'),
                          ),
                          _buildDropdownField(
                            'Program *',
                            _program,
                            ['Other', ...PROGRAM_CHOICES.map((e) => e)],
                            (value) => _updateState(value, 'program'),
                          ),
                          if (isOtherSelected)
                            _buildTextFormField(
                              'Other Program *',
                              controller: _otherProgramController,
                              validator: (value) => isOtherSelected &&
                                      (value == null || value.isEmpty)
                                  ? 'Please specify your program'
                                  : null,
                            ),
                          _buildDropdownField(
                            'Level: NTA LEVEL *',
                            _level,
                            ['4', '5', '6', '7i', '7ii', '8'],
                            (value) => _updateState(value, 'level'),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Clearance Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            'Reason for Clearance *',
                            _reason,
                            ['Complete Studies', 'Transfer', 'De Registration'],
                            (value) => _updateState(value, 'reason'),
                          ),
                          _buildDropdownField(
                            'Academic Year - Semester *',
                            _yearSemester ?? _generateSemesters().last,
                            _generateSemesters(),
                            (value) => _updateState(value, 'yearSemester'),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _submitForm,
                              child: const Text('Submit Request'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    String label, {
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.indigo),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    final effectiveItems = items.isNotEmpty ? items : ['No items available'];
    final effectiveValue =
        effectiveItems.contains(value) ? value : effectiveItems.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.indigo),
          ),
        ),
        value: effectiveValue,
        items: effectiveItems.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              maxLines: 2,
            ),
          );
        }).toList(),
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please select $label' : null,
        onChanged: onChanged,
      ),
    );
  }
}

const List<String> DEPARTMENT_CHOICES = [
  'Logistics and Transport Management (LTM)',
  'Economics, Accounting and Finance (EAF)',
  'Management Sciences (MS)',
  'Education and Mathematics (EM)',
  'Maritime Transport Management (MTM)',
  'Computing and Communication Technology (CCT)',
  'Marine, Oil and Gas Engineering (MOGE)',
  'Automotive and Mechanical Engineering (AME)',
  'Civil and Transportation Engineering (CTE)',
  'Aeronautical Engineering (AE)',
  'Electrical, Electronics and Telecommunication Engineering (EETE)',
  'Transport Safety and Environmental Engineering (TSEE)',
  'Heavy Equipment and Vehicle Inspection Centre (HEVIC) Bureau for Transport Safety and Accident Investigation (BTSAIC)',
  'Flying and Operations Management (FOM)',
  'Professional Drivers Training (PDT)',
];

const List<String> PROGRAM_CHOICES = [
  "Bachelor's Degree in Human Resource Management",
  "Bachelor's Degree in Business Administration",
  "Bachelor's Degree in Marketing and Public Relations",
  "Bachelor's Degree in Accounting and Transport Finance",
  "Bachelor's Degree in Aircraft Maintenance Engineering",
  "Bachelor's Degree in Education with Mathematics and Information Technology",
  "Bachelor's Degree in Automobile Engineering",
  "Bachelor's Degree in Mechanical Engineering",
  "Bachelor's Degree in Procurement and Logistics Management",
  "Bachelor's Degree in Information Technology",
  "Bachelor's Degree in Computer Science",
  "Bachelor's Degree in Logistics and Transport Management",
];
