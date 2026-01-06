import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class ManageBoothTypesScreen extends StatefulWidget {
  const ManageBoothTypesScreen({super.key});

  @override
  State<ManageBoothTypesScreen> createState() => _ManageBoothTypesScreenState();
}

class _ManageBoothTypesScreenState extends State<ManageBoothTypesScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> boothTypes = <Map<String, dynamic>>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoothTypes();
  }

  Future<void> _loadBoothTypes() async {
    setState(() => _isLoading = true);
    final loaded = await _db.getBoothTypes();
    if (!mounted) return;
    final currentUser = _db.getCurrentUser();
    final role = (currentUser?.role ?? '').toLowerCase();
    final currentOrganizerId = currentUser?.id;

    final visible = role == 'organizer' && currentOrganizerId != null
        ? loaded.where((row) {
            final organizerId = (row['organizerId'] as num?)?.toInt();
            return organizerId == null || organizerId == currentOrganizerId;
          }).toList()
        : loaded;

    setState(() {
      boothTypes = visible;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Booth Types'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : boothTypes.isEmpty
              ? const Center(child: Text('No booth types found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: boothTypes.length,
                  itemBuilder: (context, index) {
                    final boothType = boothTypes[index];
                    return _buildBoothTypeCard(boothType);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBoothType,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addBoothType() async {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();
    final priceController = TextEditingController();
    final featuresController = TextEditingController();

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Add Booth Type'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  TextFormField(
                    controller: sizeController,
                    decoration: const InputDecoration(labelText: 'Size (e.g., 5x5m)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a size' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (e.g., \$1,000)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a price' : null,
                  ),
                  TextFormField(
                    controller: featuresController,
                    decoration: const InputDecoration(labelText: 'Features (comma separated)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;
    final features = featuresController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      await _db.createBoothType(
        name: nameController.text.trim(),
        size: sizeController.text.trim(),
        price: priceController.text.trim(),
        features: features,
      );
      await _loadBoothTypes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create booth type: $e')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booth type created')),
    );
  }

  Widget _buildBoothTypeCard(Map<String, dynamic> boothType) {
    final currentUser = _db.getCurrentUser();
    final role = (currentUser?.role ?? '').toLowerCase();
    final boothTypeOrganizerId = (boothType['organizerId'] as num?)?.toInt();
    final canModify = role != 'organizer' || (boothTypeOrganizerId != null && boothTypeOrganizerId == currentUser?.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boothType['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    boothType['size'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  boothType['price'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (boothType['features'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .map((feature) {
              return Chip(
                label: Text(
                  feature,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.blue),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: canModify
                        ? () => _editBoothType(boothType)
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You can only edit booth types you created.')),
                            );
                          },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: canModify
                        ? () {
                            _deleteBoothType(boothType);
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You can only delete booth types you created.')),
                            );
                          },
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editBoothType(Map<String, dynamic> boothType) async {
    final nameController = TextEditingController(text: boothType['name']?.toString() ?? '');
    final sizeController = TextEditingController(text: boothType['size']?.toString() ?? '');
    final priceController = TextEditingController(text: boothType['price']?.toString() ?? '');
    final featuresController = TextEditingController(
      text: (boothType['features'] as List?)?.join(', ') ?? '',
    );

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Edit Booth Type'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  TextFormField(
                    controller: sizeController,
                    decoration: const InputDecoration(labelText: 'Size (e.g., 5x5m)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a size' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (e.g., \$1,000)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a price' : null,
                  ),
                  TextFormField(
                    controller: featuresController,
                    decoration: const InputDecoration(labelText: 'Features (comma separated)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    final features = featuresController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      final id = (boothType['id'] as num?)?.toInt();
      if (id == null) throw Exception('Missing booth type id');
      await _db.updateBoothType(
        id: id,
        name: nameController.text.trim(),
        size: sizeController.text.trim(),
        price: priceController.text.trim(),
        features: features,
      );
      await _loadBoothTypes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update booth type: $e')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booth type updated')),
    );
  }

  Future<void> _deleteBoothType(Map<String, dynamic> boothType) async {
    final id = (boothType['id'] as num?)?.toInt();
    if (id == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Booth Type'),
          content: Text('Delete "${boothType['name']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (confirm != true) return;
    try {
      await _db.deleteBoothType(id);
      await _loadBoothTypes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booth type deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete booth type: $e')));
    }
  }
}
