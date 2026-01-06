// lib/screens/booth_list_screen.dart
import 'package:flutter/material.dart';
import '../models/booth_application.dart';
import '../services/database_service.dart';

class BoothListScreen extends StatefulWidget {
  const BoothListScreen({super.key});

  @override
  State<BoothListScreen> createState() => _BoothListScreenState();
}

class _BoothListScreenState extends State<BoothListScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<BoothApplication> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _dbService.getAllBoothApplications();
      // Filter based on current user: exhibitors should only see their own apps
      final currentUser = _dbService.getCurrentUser();
      List<BoothApplication> visible = apps;
      if (currentUser != null && currentUser.role == 'exhibitor') {
        visible = apps.where((a) => a.userId == currentUser.id).toList();
      }
      setState(() {
        _applications = visible;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading applications: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications.where((a) => a.status == 'Pending').toList();
    final approved = _applications.where((a) => a.status == 'Approved').toList();
    final rejected = _applications.where((a) => a.status == 'Rejected').toList();
    final cancelled = _applications.where((a) => a.status == 'Cancelled').toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Pending (${pending.length})'),
                        Tab(text: 'Approved (${approved.length})'),
                        Tab(text: 'Rejected (${rejected.length})'),
                        Tab(text: 'Cancelled (${cancelled.length})'),
                      ],
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurple,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildApplicationsList(pending, status: 'Pending'),
                        _buildApplicationsList(approved, status: 'Approved'),
                        _buildApplicationsList(rejected, status: 'Rejected'),
                        _buildApplicationsList(cancelled, status: 'Cancelled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildApplicationsList(List<BoothApplication> apps, {required String status}) {
    if (apps.isEmpty) {
      return Center(child: Text('No $status applications'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isPending = app.status == 'Pending';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(app.companyName.isNotEmpty ? app.companyName : app.exhibitorName),
            subtitle: Text('Booth ${app.boothId} • Exhibition ${app.exhibitionId}'),
            isThreeLine: app.decisionReason.isNotEmpty,
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  app.status,
                  style: TextStyle(
                    color: app.status == 'Pending'
                        ? Colors.orange
                        : app.status == 'Approved'
                            ? Colors.green
                            : app.status == 'Rejected'
                                ? Colors.red
                                : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isPending)
                  IconButton(
                    tooltip: 'Edit (Pending only)',
                    icon: const Icon(Icons.edit, color: Colors.deepPurple),
                    onPressed: () => _editPendingApplication(app),
                  ),
                if (isPending)
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => _cancelApplication(app),
                  ),
              ],
            ),
            onTap: app.decisionReason.isEmpty
                ? null
                : () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Decision Reason'),
                        content: Text(app.decisionReason),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
          ),
        );
      },
    );
  }

  Future<void> _editPendingApplication(BoothApplication app) async {
    final exhibitProfileController = TextEditingController(text: app.exhibitProfile);
    final companyDescController = TextEditingController(text: app.companyDescription);

    final Map<String, bool> addOns = {
      'Additional furniture': app.addItems.contains('Additional furniture'),
      'Promotional spot': app.addItems.contains('Promotional spot'),
      'Extended WiFi': app.addItems.contains('Extended WiFi'),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Application'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: companyDescController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Company Description'),
                      ),
                      TextFormField(
                        controller: exhibitProfileController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Exhibit Profile/Description'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter exhibit profile' : null,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add-ons',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ),
                      ...addOns.entries.map((e) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(e.key),
                          value: e.value,
                          onChanged: (v) {
                            setDialogState(() {
                              addOns[e.key] = v ?? false;
                            });
                          },
                        );
                      }).toList(),
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
      },
    );

    if (saved != true) return;
    final selectedAddItems = addOns.entries.where((e) => e.value).map((e) => e.key).toList();

    try {
      await _dbService.updateBoothApplication(
        app.copyWith(
          companyDescription: companyDescController.text.trim(),
          exhibitProfile: exhibitProfileController.text.trim(),
          addItems: selectedAddItems,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      await _loadApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update application: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelApplication(BoothApplication app) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Cancel Application'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel Application', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await _dbService.updateBoothApplicationStatusWithReason(
        app.id ?? 0,
        'Cancelled',
        reason: reasonController.text.trim(),
      );
      await _loadApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
      );
    }
  }
}