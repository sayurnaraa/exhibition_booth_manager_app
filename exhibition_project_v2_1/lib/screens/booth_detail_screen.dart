// lib/screens/booth_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/booth.dart';
// Import the map screen here
import 'public/booth_map_screen.dart';

class BoothDetailScreen extends StatelessWidget {
  final Booth booth;
  const BoothDetailScreen({super.key, required this.booth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${booth.name} (${booth.id})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- NEW: View Floor Plan Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BoothMapScreen()),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Floor Plan Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade50,
                  foregroundColor: Colors.deepPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.deepPurple.shade200),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // -----------------------------------

            // Booth Name and Exhibitor
            Text(
              booth.exhibitor,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Location ID: ${booth.id}',
              style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            ),
            const Divider(height: 32),

            // Key Metrics Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Status', booth.status, _getStatusColor(booth.status)),
                    _buildMetric('Leads', '${booth.leadsCount}', Colors.deepPurple),
                    _buildMetric('Staff', '3', Colors.orange), // Example metric
                  ],
                ),
              ),
            ),
            const Divider(height: 32),

            // Management Actions
            const Text('Management Tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildActionButton(context, 'Scan QR for Check-in', Icons.qr_code_scanner, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Scanner launched!')),
              );
            }),
            _buildActionButton(context, 'View Lead List', Icons.people_alt_outlined, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lead List screen navigation')),
              );
            }),
            _buildActionButton(context, 'Update Booth Status', Icons.edit_note, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Status Update form opened')),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Helper widget for displaying key metrics
  Widget _buildMetric(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // Helper widget for action buttons
  Widget _buildActionButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    );
  }

  // Helper for status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Occupied': return Colors.green;
      case 'Available': return Colors.blueGrey;
      case 'Maintenance': return Colors.red;
      default: return Colors.grey;
    }
  }
}