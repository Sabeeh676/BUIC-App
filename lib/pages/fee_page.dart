import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeePage extends StatefulWidget {
  const FeePage({super.key});

  @override
  _FeePageState createState() => _FeePageState();
}

class _FeePageState extends State<FeePage> {
  List<Map<String, dynamic>> _feeData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFeeDataFromFirestore();
  }

  Future<void> _fetchFeeDataFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("You must be logged in to view fee details.");
      }
      final studentId = user.email!.split('@')[0];

      final feeCollection = FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('feeDetails');
      final QuerySnapshot snapshot = await feeCollection.get();

      final List<Map<String, dynamic>> fetchedData = snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();

      fetchedData.sort((a, b) {
        try {
          DateTime dateA = _parseDate(a['dueDate']);
          DateTime dateB = _parseDate(b['dueDate']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _feeData = fetchedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error fetching fee data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseDate(String date) {
    // Assuming date format is DD/MM/YYYY
    final parts = date.split('/');
    if (parts.length != 3) throw const FormatException('Invalid date format');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _feeData.isEmpty
          ? const Center(child: Text('No fee data available.'))
          : RefreshIndicator(
              onRefresh: _fetchFeeDataFromFirestore,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _feeData.length,
                itemBuilder: (context, index) {
                  final fee = _feeData[index];
                  return _buildFeeCard(
                    term: fee['term'],
                    challanNo: fee['challanNo'],
                    amount: fee['amount'],
                    dueDate: fee['dueDate'],
                    status: fee['status'],
                    statusColor: fee['status'] == 'Paid'
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                    depositDate: fee['depositDate'],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFeeCard({
    required String term,
    required String challanNo,
    required String amount,
    required String dueDate,
    required String status,
    required Color statusColor,
    String? depositDate,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 14,
                  ),
                  child: Text(
                    term,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInfoRowWithIcon(
              Icons.receipt_long_rounded,
              'Challan No',
              challanNo,
            ),
            _buildInfoRowWithIcon(Icons.attach_money_rounded, 'Amount', amount),
            _buildInfoRowWithIcon(
              Icons.calendar_today_rounded,
              'Due Date',
              dueDate,
            ),
            if (status == 'Paid' &&
                depositDate != null &&
                depositDate.isNotEmpty) ...[
              const Divider(),
              _buildInfoRowWithIcon(
                Icons.check_circle_rounded,
                'Deposit Date',
                depositDate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
