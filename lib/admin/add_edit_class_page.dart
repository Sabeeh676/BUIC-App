import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddEditClassPage extends StatefulWidget {
  final String courseId;
  final DocumentSnapshot? classDoc;

  const AddEditClassPage({super.key, required this.courseId, this.classDoc});

  @override
  State<AddEditClassPage> createState() => _AddEditClassPageState();
}

class _Session {
  String day;
  TextEditingController startTimeController;
  TextEditingController endTimeController;
  String? location;

  _Session({
    required this.day,
    String startTime = '',
    String endTime = '',
    this.location,
  }) : startTimeController = TextEditingController(text: startTime),
       endTimeController = TextEditingController(text: endTime);

  Map<String, dynamic> toMap() => {
    'day': day,
    'start_time': startTimeController.text,
    'end_time': endTimeController.text,
    'location': location,
  };

  void dispose() {
    startTimeController.dispose();
    endTimeController.dispose();
  }
}

class _AddEditClassPageState extends State<AddEditClassPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _classNameController;
  late TextEditingController _searchController;

  String? _selectedTeacherId;
  List<String> _selectedStudentIds = [];
  List<_Session> _sessions = [];
  List<DocumentSnapshot> _allStudents = [];
  List<DocumentSnapshot> _filteredStudents = [];
  bool _isLoading = false;

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final List<String> _halls = ["HL-9", "HL-11", "HL-17", "NC-16"];

  @override
  void initState() {
    super.initState();
    final classData = widget.classDoc?.data() as Map<String, dynamic>?;

    _classNameController = TextEditingController(
      text: widget.classDoc?.id ?? '',
    );
    _searchController = TextEditingController();

    _selectedTeacherId = classData?['teacher_id'];
    _selectedStudentIds = List<String>.from(classData?['students'] ?? []);

    if (classData?['schedule'] != null) {
      final scheduleData = List<Map<String, dynamic>>.from(
        classData!['schedule'],
      );
      _sessions = scheduleData
          .map(
            (s) => _Session(
              day: s['day'],
              startTime: s['start_time'] ?? '',
              endTime: s['end_time'] ?? '',
              location: s['location'],
            ),
          )
          .toList();
    }

    _fetchStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _searchController.dispose();
    for (var session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      setState(() {
        _allStudents = snapshot.docs;
        _filteredStudents = _allStudents;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((doc) {
        final name = (doc['name'] as String).toLowerCase();
        final enrollment = (doc['enrollment'] as String).toLowerCase();
        return name.contains(query) || enrollment.contains(query);
      }).toList();
    });
  }

  Future<void> _saveClass() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final schedule = _sessions.map((s) => s.toMap()).toList();

      final classData = {
        'teacher_id': _selectedTeacherId,
        'students': _selectedStudentIds,
        'schedule': schedule,
      };

      try {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('classes')
            .doc(_classNameController.text)
            .set(classData, SetOptions(merge: true));

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving class: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _toggleDay(String day) {
    setState(() {
      final index = _sessions.indexWhere((s) => s.day == day);
      if (index != -1) {
        _sessions[index].dispose();
        _sessions.removeAt(index);
      } else {
        _sessions.add(_Session(day: day));
        // Sort sessions to keep a consistent order
        _sessions.sort(
          (a, b) =>
              _daysOfWeek.indexOf(a.day).compareTo(_daysOfWeek.indexOf(b.day)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classDoc == null ? 'Add Class' : 'Edit Class'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveClass,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Class Details'),
                    _buildTextField(
                      controller: _classNameController,
                      label: 'Class Name (e.g., BSCS-8A)',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a class name' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTeacherSelector(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Class Schedule'),
                    _buildScheduleEditor(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Enroll Students'),
                    _buildStudentSelector(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildTeacherSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<String>(
          value: _selectedTeacherId,
          decoration: InputDecoration(
            labelText: 'Assign Teacher',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {
              _selectedTeacherId = value;
            });
          },
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
          }).toList(),
          validator: (value) =>
              value == null ? 'Please assign a teacher' : null,
        );
      },
    );
  }

  Widget _buildScheduleEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select class days:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _daysOfWeek.map((day) {
            final isSelected = _sessions.any((s) => s.day == day);
            return ChoiceChip(
              label: Text(day[0].toUpperCase() + day.substring(1)),
              selected: isSelected,
              onSelected: (_) => _toggleDay(day),
              selectedColor: Theme.of(context).primaryColor,
              labelStyle:
                  TextStyle(color: isSelected ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];
            return _buildSessionCard(session, key: ValueKey(session.day));
          },
        ),
      ],
    );
  }

  Widget _buildSessionCard(_Session session, {Key? key}) {
    // Ensure the dropdown can display a saved value even if it's not in the default list.
    final List<String> hallItems = List.from(_halls);
    if (session.location != null && !hallItems.contains(session.location)) {
      hallItems.add(session.location!);
    }

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.day[0].toUpperCase() + session.day.substring(1),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerField(
                    context: context,
                    controller: session.startTimeController,
                    labelText: 'Start Time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerField(
                    context: context,
                    controller: session.endTimeController,
                    labelText: 'End Time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: session.location,
              decoration: const InputDecoration(
                labelText: 'Location/Hall',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  session.location = value;
                });
              },
              items: hallItems.map((hall) {
                return DropdownMenuItem(
                  value: hall,
                  child: Text(hall),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
  }) {
    return InkWell(
      onTap: () => _pickTime(context, controller),
      child: IgnorePointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(
      BuildContext context, TextEditingController controller) async {
    final initialTime = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        controller.text = pickedTime.format(context);
      });
    }
  }

  Widget _buildStudentSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Students by Name or ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 400, // Constrain height to make it scrollable
            child: _filteredStudents.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      final isSelected = _selectedStudentIds.contains(
                        student.id,
                      );
                      return CheckboxListTile(
                        title: Text(student['name']),
                        subtitle: Text(student.id),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedStudentIds.add(student.id);
                            } else {
                              _selectedStudentIds.remove(student.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
