import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/exhibition.dart';
import '../../models/login_user.dart';

class ManageExhibitionsScreen extends StatefulWidget {
  const ManageExhibitionsScreen({super.key});

  @override
  State<ManageExhibitionsScreen> createState() => _ManageExhibitionsScreenState();
}

class _ManageExhibitionsScreenState extends State<ManageExhibitionsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Exhibition> _exhibitions = [];
  bool _isLoading = true;
  List<LoginUser> _organizers = [];

  @override
  void initState() {
    super.initState();
    _loadExhibitions();
    _loadOrganizers();
  }

  Future<void> _loadOrganizers() async {
    try {
      final users = await _db.getAllUsers();
      if (!mounted) return;
      setState(() {
        _organizers = users.where((u) => (u.role ?? '').toLowerCase() == 'organizer' && u.id != null).toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadExhibitions() async {
    setState(() => _isLoading = true);
    final exs = await _db.getAllExhibitions();
    setState(() {
      _exhibitions = exs;
      _isLoading = false;
    });
  }

  Future<void> _confirmAndDeleteExhibition(Exhibition exhibition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exhibition'),
        content: Text('Are you sure you want to delete "${exhibition.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteExhibition(exhibition.id!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exhibition deleted')));
        await _loadExhibitions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete exhibition: $e')));
      }
    }
  }

  Future<void> _openUpsertDialog({Exhibition? initial}) async {
    final isEdit = initial != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: initial?.name ?? '');
    final descriptionController = TextEditingController(text: initial?.description ?? '');
    final locationController = TextEditingController(text: initial?.location ?? '');
    final startDateController = TextEditingController(text: initial?.startDate ?? '');
    final endDateController = TextEditingController(text: initial?.endDate ?? '');
    final statusController = TextEditingController(text: initial?.status ?? 'Active');
    final totalBoothsController = TextEditingController(text: (initial?.totalBooths ?? 0).toString());
    final categoriesController = TextEditingController(text: (initial?.industryCategories ?? const <String>[]).join(', '));

    bool isPublished = initial?.isPublished ?? false;
    bool blockAdjacentCompetitors = initial?.blockAdjacentCompetitors ?? false;
    int? organizerId = initial?.organizerId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Exhibition' : 'Create Exhibition'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int?>(
                          value: organizerId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Organizer (optional)'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Unassigned', overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                            ..._organizers
                                .map(
                                  (u) => DropdownMenuItem<int?>(
                                    value: u.id,
                                    child: Text(
                                      u.fullName?.trim().isNotEmpty == true ? '${u.fullName} (${u.email})' : u.email,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (v) => setDialogState(() => organizerId = v),
                        ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Location'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a location' : null,
                      ),
                      TextFormField(
                        controller: startDateController,
                        decoration: const InputDecoration(labelText: 'Start Date'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a start date' : null,
                      ),
                      TextFormField(
                        controller: endDateController,
                        decoration: const InputDecoration(labelText: 'End Date'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter an end date' : null,
                      ),
                      TextFormField(
                        controller: statusController,
                        decoration: const InputDecoration(labelText: 'Status'),
                      ),
                      TextFormField(
                        controller: totalBoothsController,
                        decoration: const InputDecoration(labelText: 'Total Booths'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final parsed = int.tryParse((v ?? '').trim());
                          if (parsed == null || parsed < 0) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: categoriesController,
                        decoration: const InputDecoration(labelText: 'Industry Categories (comma separated)'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Published'),
                        value: isPublished,
                        onChanged: (v) => setDialogState(() => isPublished = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Block adjacent competitors'),
                        value: blockAdjacentCompetitors,
                        onChanged: (v) => setDialogState(() => blockAdjacentCompetitors = v),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.of(c).pop(true);
                  },
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      nameController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      startDateController.dispose();
      endDateController.dispose();
      statusController.dispose();
      totalBoothsController.dispose();
      categoriesController.dispose();
      return;
    }

    try {
      final cats = categoriesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final totalBooths = int.tryParse(totalBoothsController.text.trim()) ?? 0;

      if (isEdit) {
        await _db.updateExhibition(
          initial.copyWith(
            organizerId: organizerId,
            name: nameController.text.trim(),
            description: descriptionController.text.trim(),
            startDate: startDateController.text.trim(),
            endDate: endDateController.text.trim(),
            location: locationController.text.trim(),
            status: statusController.text.trim().isEmpty ? 'Active' : statusController.text.trim(),
            totalBooths: totalBooths,
            isPublished: isPublished,
            blockAdjacentCompetitors: blockAdjacentCompetitors,
            industryCategories: cats,
          ),
        );
      } else {
        await _db.createExhibition(
          Exhibition(
            organizerId: organizerId,
            name: nameController.text.trim(),
            description: descriptionController.text.trim(),
            startDate: startDateController.text.trim(),
            endDate: endDateController.text.trim(),
            location: locationController.text.trim(),
            status: statusController.text.trim().isEmpty ? 'Active' : statusController.text.trim(),
            totalBooths: totalBooths,
            isPublished: isPublished,
            blockAdjacentCompetitors: blockAdjacentCompetitors,
            industryCategories: cats,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Exhibition updated' : 'Exhibition created')),
      );
      await _loadExhibitions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save exhibition: $e')));
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      startDateController.dispose();
      endDateController.dispose();
      statusController.dispose();
      totalBoothsController.dispose();
      categoriesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Exhibitions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openUpsertDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _exhibitions.length,
              itemBuilder: (context, i) {
                final e = _exhibitions[i];
                return Card(
                  child: ListTile(
                    title: Text(e.name),
                    subtitle: Text('${e.startDate} - ${e.endDate} • ${e.location} • ${e.isPublished ? 'Published' : 'Unpublished'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${e.totalBooths} booths'),
                        const SizedBox(width: 8),
                        Switch(
                          value: e.isPublished,
                          onChanged: (v) async {
                            try {
                              await _db.updateExhibition(e.copyWith(isPublished: v));
                              await _loadExhibitions();
                            } catch (err) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update publish status: $err')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Edit exhibition',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openUpsertDialog(initial: e),
                        ),
                        IconButton(
                          tooltip: 'Delete exhibition',
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _confirmAndDeleteExhibition(e),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
