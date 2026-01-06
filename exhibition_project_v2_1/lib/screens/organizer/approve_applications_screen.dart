import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/booth_application.dart';
import '../../models/exhibition.dart';

class ApproveApplicationsScreen extends StatefulWidget {
  const ApproveApplicationsScreen({super.key});

  @override
  State<ApproveApplicationsScreen> createState() =>
      _ApproveApplicationsScreenState();
}

class _ApproveApplicationsScreenState extends State<ApproveApplicationsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<BoothApplication> _applications = [];
  List<Exhibition> _myExhibitions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final exhibitions = await _dbService.getMyExhibitions();
      final allowedIds = exhibitions.map((e) => e.id).whereType<int>().toSet();

      final allApps = await _dbService.getAllBoothApplications();
      final apps = allowedIds.isEmpty
          ? <BoothApplication>[]
          : allApps.where((a) => allowedIds.contains(a.exhibitionId)).toList();
      setState(() {
        _applications = apps;
        _myExhibitions = exhibitions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading applications: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications.where((a) => a.status == 'Pending').toList();
    final approved = _applications.where((a) => a.status == 'Approved').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Applications'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_myExhibitions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'No exhibitions found for your organizer account.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  TabBar(
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Approved (${approved.length})'),
                    ],
                    labelColor: Colors.deepPurple,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepPurple,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Pending
                        ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: pending.length,
                          itemBuilder: (context, index) {
                            return _buildApplicationCard(pending[index], isPending: true);
                          },
                        ),
                        // Approved
                        ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: approved.length,
                          itemBuilder: (context, index) {
                            return _buildApplicationCard(approved[index], isPending: false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildApplicationCard(BoothApplication application, {required bool isPending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(application.exhibitorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Booth: ${application.boothId}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isPending ? 'Pending' : 'Approved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPending ? Colors.orange : Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [Icon(Icons.event, size: 16, color: Colors.grey[600]), const SizedBox(width: 4), Expanded(child: Text('Exhibition ID: ${application.exhibitionId}', style: TextStyle(fontSize: 12, color: Colors.grey[600])))]),
          const SizedBox(height: 8),
          Row(children: [Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]), const SizedBox(width: 4), Text('Applied: ${application.createdAt}', style: TextStyle(fontSize: 12, color: Colors.grey[600]))]),
          const SizedBox(height: 12),
          Text('Contact: ${application.email}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          if (application.decisionReason.trim().isNotEmpty) ...[
            Text(
              'Decision reason: ${application.decisionReason}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
          ],
          if (isPending)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final reason = await _promptReason(
                        title: 'Reject application',
                        hint: 'Reason for rejection',
                      );
                      if (reason == null) return;
                      await _dbService.updateBoothApplicationStatusWithReason(application.id ?? 0, 'Rejected', reason: reason);
                      await _loadApplications();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application rejected'), backgroundColor: Colors.red));
                    },
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Reject', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final reason = await _promptReason(
                        title: 'Withdraw application',
                        hint: 'Reason for withdrawal',
                      );
                      if (reason == null) return;
                      await _dbService.updateBoothApplicationStatusWithReason(application.id ?? 0, 'Withdrawn', reason: reason);
                      await _loadApplications();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application withdrawn'), backgroundColor: Colors.blueGrey));
                    },
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Withdraw', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _dbService.updateBoothApplicationStatusWithReason(application.id ?? 0, 'Approved', reason: '');
                      await _loadApplications();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application approved'), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final reason = await _promptReason(
                        title: 'Cancel booking',
                        hint: 'Reason for cancellation',
                      );
                      if (reason == null) return;
                      await _dbService.updateBoothApplicationStatusWithReason(application.id ?? 0, 'Cancelled', reason: reason);
                      await _loadApplications();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.redAccent));
                    },
                    icon: const Icon(Icons.cancel, size: 14),
                    label: const Text('Cancel booking', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<String?> _promptReason({required String title, required String hint}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: hint),
              autofocus: true,
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a reason' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(c).pop(controller.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}
