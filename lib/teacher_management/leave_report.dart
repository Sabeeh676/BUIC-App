import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveReport extends StatefulWidget {
  const LeaveReport({super.key});

  @override
  State<LeaveReport> createState() => _LeaveReportState();
}

class _LeaveReportState extends State<LeaveReport> {
  Stream<QuerySnapshot>? _leaveRequestsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // First, get the teacher's document ID from their email
      FirebaseFirestore.instance
          .collection('teachers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get()
          .then((teacherSnapshot) {
        if (teacherSnapshot.docs.isNotEmpty) {
          final teacherId = teacherSnapshot.docs.first.id;
          // Now, create the stream to listen for leave requests
          setState(() {
            _leaveRequestsStream = FirebaseFirestore.instance
                .collection('leaveRequests')
                .where('teacherId', isEqualTo: teacherId)
                .orderBy('requestedAt', descending: true)
                .snapshots();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave Report'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _leaveRequestsStream == null
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loader while finding teacher ID
          : StreamBuilder<QuerySnapshot>(
              stream: _leaveRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('You have not submitted any leave requests.'));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final leaveDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: leaveDocs.length,
                  itemBuilder: (context, index) {
                    final request = leaveDocs[index];
                    final data = request.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'Pending';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _getStatusColor(status).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        title: Text(
                          data['subject'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${DateFormat('dd MMM yyyy').format((data['startDate'] as Timestamp).toDate())} - ${DateFormat('dd MMM yyyy').format((data['endDate'] as Timestamp).toDate())}',
                          ),
                        ),
                        trailing: Chip(
                          label: Text(status),
                          backgroundColor: _getStatusColor(status),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Declined':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}