import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class ManageAddOnsScreen extends StatefulWidget {
  const ManageAddOnsScreen({super.key});

  @override
  State<ManageAddOnsScreen> createState() => _ManageAddOnsScreenState();
}

class _ManageAddOnsScreenState extends State<ManageAddOnsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _addOns = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _db.getCurrentUser();
      final organizerId = user?.id;
      if (organizerId == null) {
        setState(() {
          _addOns = <Map<String, dynamic>>[];
          _loading = false;
        });
        return;
      }
      final rows = await _db.getAddOnsForOrganizer(organizerId);
      if (!mounted) return;
      setState(() {
        _addOns = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load add-ons: $e')));
    }
  }

  Future<void> _addAddOn() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Add Add-on'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (optional, e.g., \$100)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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
    try {
      await _db.createAddOn(
        name: nameController.text.trim(),
        price: priceController.text.trim().isEmpty ? null : priceController.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add-on created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create add-on: $e')));
    }
  }

  Future<void> _editAddOn(Map<String, dynamic> addOn) async {
    final id = (addOn['id'] as num?)?.toInt();
    if (id == null) return;

    final nameController = TextEditingController(text: addOn['name']?.toString() ?? '');
    final priceController = TextEditingController(text: addOn['price']?.toString() ?? '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Edit Add-on'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (optional, e.g., \$100)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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

    try {
      await _db.updateAddOn(
        id: id,
        name: nameController.text.trim(),
        price: priceController.text.trim().isEmpty ? null : priceController.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add-on updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update add-on: $e')));
    }
  }

  Future<void> _deleteAddOn(Map<String, dynamic> addOn) async {
    final id = (addOn['id'] as num?)?.toInt();
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Add-on'),
        content: Text('Delete "${addOn['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteAddOn(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add-on deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete add-on: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Add-ons'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _addOns.isEmpty
              ? const Center(child: Text('No add-ons yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addOns.length,
                  itemBuilder: (context, index) {
                    final a = _addOns[index];
                    final name = a['name']?.toString() ?? '';
                    final price = a['price']?.toString();
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: (price != null && price.trim().isNotEmpty) ? Text(price) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editAddOn(a)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteAddOn(a)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAddOn,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}
