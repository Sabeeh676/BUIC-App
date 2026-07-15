import 'package:buic_app/admin/add_edit_fee_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStudentFeesPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ManageStudentFeesPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ManageStudentFeesPage> createState() => _ManageStudentFeesPageState();
}

class _ManageStudentFeesPageState extends State<ManageStudentFeesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _navigateToAddEditPage({DocumentSnapshot? feeDoc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditFeePage(
          studentId: widget.studentId,
          feeDoc: feeDoc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fees for ${widget.studentName}"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('students')
            .doc(widget.studentId)
            .collection('feeDetails')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No fee details found for this student.'));
          }

          final feeDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: feeDocs.length,
            itemBuilder: (context, index) {
              final feeDoc = feeDocs[index];
              final feeData = feeDoc.data() as Map<String, dynamic>;
              final status = feeData['status'] ?? 'N/A';
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(feeData['term'] ?? 'No Term'),
                  subtitle: Text(
                      'Challan: ${feeData['challanNo']} - Amount: ${feeData['amount']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(status),
                        backgroundColor: status == 'Paid' ? Colors.green.shade100 : Colors.red.shade100,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _navigateToAddEditPage(feeDoc: feeDoc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _firestore
                              .collection('students')
                              .doc(widget.studentId)
                              .collection('feeDetails')
                              .doc(feeDoc.id)
                              .delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditPage(),
        child: const Icon(Icons.add),
        tooltip: 'Add Fee Record',
      ),
    );
  }
}
