import 'package:buic_app/teacher_management/teacher_data_service.dart';
import 'package:flutter/material.dart';

class CourseClassSelector extends StatefulWidget {
  final Function(String? courseId, List<String> classIds) onSelectionChanged;
  final bool multiSelection;
  final String? initialCourseId;
  final List<String>? initialClassIds;

  const CourseClassSelector({
    super.key,
    required this.onSelectionChanged,
    this.multiSelection = true,
    this.initialCourseId,
    this.initialClassIds,
  });

  @override
  _CourseClassSelectorState createState() => _CourseClassSelectorState();
}

class _CourseClassSelectorState extends State<CourseClassSelector> {
  final TeacherDataService _dataService = TeacherDataService();
  String? _selectedCourseId;
  List<String> _selectedClassIds = [];
  List<String> _availableClasses = [];

  @override
  void initState() {
    super.initState();
    _dataService.addListener(_onDataUpdated);
    _selectedCourseId = widget.initialCourseId;
    _selectedClassIds = widget.initialClassIds ?? [];
    if (_dataService.isDataLoaded && _selectedCourseId != null) {
      _availableClasses = _dataService.getClassesForCourse(_selectedCourseId!);
    }
  }

  @override
  void dispose() {
    _dataService.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) {
      setState(() {
        // Potentially update available classes if the underlying data changes
        if (_selectedCourseId != null) {
          _availableClasses =
              _dataService.getClassesForCourse(_selectedCourseId!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataService.isDataLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading teacher's course data..."),
            ],
          ),
        ),
      );
    }

    final courses = _dataService.courses;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Course",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: courses.entries.map((entry) {
                final isSelected = _selectedCourseId == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCourseId = entry.key;
                        _availableClasses = _dataService.getClassesForCourse(
                          _selectedCourseId!,
                        );
                      } else {
                        _selectedCourseId = null;
                        _availableClasses.clear();
                      }
                      _selectedClassIds.clear();
                      widget.onSelectionChanged(
                        _selectedCourseId,
                        _selectedClassIds,
                      );
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  backgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedCourseId != null) ...[
              const Divider(height: 24),
              Text(
                widget.multiSelection ? "Select Class(es)" : "Select Class",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_availableClasses.isEmpty)
                const Text('No classes found for this course.')
              else
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _availableClasses.map((classId) {
                    final isSelected = _selectedClassIds.contains(classId);
                    return ChoiceChip(
                      label: Text(classId),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!widget.multiSelection) {
                              _selectedClassIds.clear();
                            }
                            _selectedClassIds.add(classId);
                          } else {
                            _selectedClassIds.remove(classId);
                          }
                          widget.onSelectionChanged(
                            _selectedCourseId,
                            _selectedClassIds,
                          );
                        });
                      },
                      selectedColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade400,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
