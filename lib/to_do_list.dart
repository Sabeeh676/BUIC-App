import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For JSON encoding/decoding

class ToDoList extends StatefulWidget {
  const ToDoList({super.key});

  @override
  _ToDoListState createState() => _ToDoListState();
}

class _ToDoListState extends State<ToDoList> {
  final TextEditingController taskController = TextEditingController();
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks(); // Load tasks when the widget initializes
  }

  // Load tasks from SharedPreferences
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks');

    if (tasksString != null) {
      setState(() {
        tasks = List<Map<String, dynamic>>.from(
          jsonDecode(tasksString).map((task) => task as Map<String, dynamic>),
        );
      });
    }
  }

  // Save tasks to SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String tasksString = jsonEncode(tasks);
    await prefs.setString('tasks', tasksString);
  }

  void addTask(String taskName) {
    setState(() {
      tasks.insert(0, {'name': taskName, 'isDone': false});
    });
    taskController.clear();
    Navigator.of(context).pop();
    _saveTasks(); // Save tasks after adding a new one
  }

  void toggleTaskStatus(int index) {
    setState(() {
      tasks[index]['isDone'] = !tasks[index]['isDone'];
    });
    tasks.sort((a, b) => a['isDone'] ? 1 : -1);
    _saveTasks(); // Save tasks after toggling status
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Task',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon:
                      Icon(Icons.cancel, color: Theme.of(context).primaryColor),
                )
              ],
            ),
            TextField(
              controller: taskController,
              decoration: InputDecoration(
                labelText: 'What To Do',
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  if (taskController.text.trim().isNotEmpty) {
                    addTask(taskController.text.trim());
                  }
                },
                child: const Text('Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My To-Do List',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  onPressed: _showAddTaskDialog,
                  icon: Icon(Icons.add_circle, size: 30),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const Divider(color: Colors.black26),
            // Task List
            if (tasks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No tasks yet. Add one!',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: task['isDone']
                              ? Colors.green
                              : Theme.of(context).primaryColor,
                          width: 5,
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () => toggleTaskStatus(index),
                        child: Icon(
                          task['isDone']
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: task['isDone']
                              ? Colors.green
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                      title: Text(
                        task['name'],
                        style: TextStyle(
                          decoration: task['isDone']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
