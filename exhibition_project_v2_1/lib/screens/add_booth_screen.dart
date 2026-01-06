// lib/screens/add_booth_screen.dart
import 'package:flutter/material.dart';
import '../models/booth.dart';

class AddBoothScreen extends StatefulWidget {
  const AddBoothScreen({super.key});

  @override
  State<AddBoothScreen> createState() => _AddBoothScreenState();
}

class _AddBoothScreenState extends State<AddBoothScreen> {
  // Key to identify the form and run validation
  final _formKey = GlobalKey<FormState>();

  // Controllers to retrieve text field data
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _exhibitorController = TextEditingController();
  final _leadsController = TextEditingController();

  // Default status value for the dropdown
  String _selectedStatus = 'Available';

  // List of status options
  final List<String> _statusOptions = ['Available', 'Occupied', 'Maintenance'];

  @override
  void dispose() {
    // Always dispose controllers to free up memory
    _idController.dispose();
    _nameController.dispose();
    _exhibitorController.dispose();
    _leadsController.dispose();
    super.dispose();
  }

  void _saveBooth() {
    // 1. Validate the form
    if (_formKey.currentState!.validate()) {

      // 2. Create the new Booth object
      final newBooth = Booth(
        id: _idController.text,
        name: _nameController.text,
        exhibitor: _exhibitorController.text,
        status: _selectedStatus,
        leadsCount: int.tryParse(_leadsController.text) ?? 0,
      );

      // 3. Pass the new object back to the previous screen
      Navigator.pop(context, newBooth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Booth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Booth ID Input
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Booth ID (e.g., E10)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a Booth ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Booth Name Input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Booth Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Exhibitor Name Input
              TextFormField(
                controller: _exhibitorController,
                decoration: const InputDecoration(
                  labelText: 'Exhibitor Company',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the exhibitor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Current Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: _statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedStatus = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Leads Count Input (Numeric)
              TextFormField(
                controller: _leadsController,
                decoration: const InputDecoration(
                  labelText: 'Initial Leads Count',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                // No validator needed here, strictly optional (defaults to 0)
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveBooth,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('SAVE BOOTH'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}