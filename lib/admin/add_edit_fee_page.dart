import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditFeePage extends StatefulWidget {
  final String studentId;
  final DocumentSnapshot? feeDoc;

  const AddEditFeePage({
    super.key,
    required this.studentId,
    this.feeDoc,
  });

  @override
  State<AddEditFeePage> createState() => _AddEditFeePageState();
}

class _AddEditFeePageState extends State<AddEditFeePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _termController;
  late TextEditingController _challanNoController;
  late TextEditingController _amountController;
  late TextEditingController _dueDateController;
  late TextEditingController _depositDateController;
  String _status = 'Unpaid';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final feeData = widget.feeDoc?.data() as Map<String, dynamic>?;

    _termController = TextEditingController(text: feeData?['term'] ?? '');
    _challanNoController = TextEditingController(text: feeData?['challanNo'] ?? '');
    _amountController = TextEditingController(text: feeData?['amount'] ?? '');
    _dueDateController = TextEditingController(text: feeData?['dueDate'] ?? '');
    _depositDateController = TextEditingController(text: feeData?['depositDate'] ?? '');
    _status = feeData?['status'] ?? 'Unpaid';
  }

  @override
  void dispose() {
    _termController.dispose();
    _challanNoController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _depositDateController.dispose();
    super.dispose();
  }

  Future<void> _saveFee() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final feeData = {
        'term': _termController.text,
        'challanNo': _challanNoController.text,
        'amount': _amountController.text,
        'dueDate': _dueDateController.text,
        'status': _status,
        'depositDate': _depositDateController.text,
      };

      try {
        final collection = FirebaseFirestore.instance
            .collection('students')
            .doc(widget.studentId)
            .collection('feeDetails');

        if (widget.feeDoc == null) {
          await collection.add(feeData);
        } else {
          await collection.doc(widget.feeDoc!.id).update(feeData);
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving fee record: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feeDoc == null ? 'Add Fee Record' : 'Edit Fee Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveFee,
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
                  children: [
                    _buildTextField(controller: _termController, label: 'Term (e.g., Fall 2024)'),
                    _buildTextField(controller: _challanNoController, label: 'Challan No'),
                    _buildTextField(controller: _amountController, label: 'Amount', keyboardType: TextInputType.number),
                    _buildTextField(controller: _dueDateController, label: 'Due Date (e.g., 25/10/2024)'),
                    _buildTextField(controller: _depositDateController, label: 'Deposit Date (if paid)'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Unpaid', 'Paid']
                          .map((label) => DropdownMenuItem(
                                child: Text(label),
                                value: label,
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? 'Unpaid';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) => value!.isEmpty ? 'Please enter a value' : null,
      ),
    );
  }
}
