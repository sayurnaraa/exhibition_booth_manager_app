import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/booth_application.dart';

class BookingsOverviewScreen extends StatefulWidget {
  const BookingsOverviewScreen({super.key});

  @override
  State<BookingsOverviewScreen> createState() => _BookingsOverviewScreenState();
}

class _BookingsOverviewScreenState extends State<BookingsOverviewScreen> {
  final DatabaseService _db = DatabaseService();
  List<BoothApplication> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final apps = await _db.getAllBoothApplications();
    setState(() {
      _apps = apps;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(BoothApplication app, String status) async {
    await _db.updateBoothApplicationStatus(app.id!, status);
    await _load();
  }

  Future<void> _deleteApplication(BoothApplication app) async {
    final id = app.id;
    if (id == null) return;
    await _db.deleteBoothApplication(id);
    await _load();
  }

  Future<void> _openBookingActions(BoothApplication app) async {
    final id = app.id;
    if (id == null) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final addOns = app.addItems;
        final bookingWindow = (app.bookingStartDate.trim().isNotEmpty || app.bookingEndDate.trim().isNotEmpty)
            ? '${app.bookingStartDate} → ${app.bookingEndDate}'
            : 'Not specified';
        final eventWindow = (app.eventStartDate.trim().isNotEmpty || app.eventEndDate.trim().isNotEmpty)
            ? '${app.eventStartDate} → ${app.eventEndDate}'
            : 'Not specified';

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(c).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Booking #$id', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Status: ${app.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('Exhibitor: ${app.exhibitorName}'),
                Text('Company: ${app.companyName}'),
                if (app.industryCategory.trim().isNotEmpty) Text('Category: ${app.industryCategory}'),
                Text('Booth: ${app.boothId}'),
                Text('Exhibition ID: ${app.exhibitionId}'),
                const SizedBox(height: 8),
                Text('Event: $eventWindow'),
                Text('Booking: $bookingWindow'),
                const SizedBox(height: 8),
                Text('Email: ${app.email}'),
                Text('Phone: ${app.phone}'),
                if (addOns.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Add-ons: ${addOns.join(', ')}'),
                ],
                if (app.decisionReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Decision reason: ${app.decisionReason}'),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(c).pop('Approved'),
                      child: const Text('Approve'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(c).pop('Rejected'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Reject'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(c).pop('Cancelled'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text('Cancel booking'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(c).pop('DELETE'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;

    if (result == 'DELETE') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete booking'),
          content: const Text('Delete this booking permanently?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        await _deleteApplication(app);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking deleted')));
      }
      return;
    }

    await _updateStatus(app, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking updated: $result')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings Overview')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? const Center(child: Text('No bookings yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _apps.length,
                  itemBuilder: (context, i) {
                    final a = _apps[i];
                    return Card(
                      child: ListTile(
                        title: Text(a.exhibitorName),
                        subtitle: Text('Booth ${a.boothId} • Exhibition ${a.exhibitionId}'),
                        trailing: Text(a.status, style: TextStyle(color: a.status == 'Approved' ? Colors.green : Colors.orange)),
                        isThreeLine: true,
                        onTap: () => _openBookingActions(a),
                        dense: false,
                      ),
                    );
                  },
                ),
    );
  }
}
