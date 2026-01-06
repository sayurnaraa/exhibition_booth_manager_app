import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/exhibition.dart';

class ManageBoothsScreen extends StatefulWidget {
  const ManageBoothsScreen({super.key});

  @override
  State<ManageBoothsScreen> createState() => _ManageBoothsScreenState();
}

class _ManageBoothsScreenState extends State<ManageBoothsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Exhibition> _exhibitions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final exs = await _db.getAllExhibitions();
    setState(() {
      _exhibitions = exs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Booths')),
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
                    subtitle: Text('${e.totalBooths} booths • ${e.status}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () {},
                  ),
                );
              },
            ),
    );
  }
}
