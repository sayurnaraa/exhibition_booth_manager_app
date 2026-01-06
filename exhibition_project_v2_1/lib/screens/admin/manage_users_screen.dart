import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/login_user.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final DatabaseService _db = DatabaseService();
  List<LoginUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _db.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _deleteUser(int id) async {
    await _db.deleteUser(id);
    await _loadUsers();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (context, i) {
                final u = _users[i];
                return Card(
                  child: ListTile(
                    title: Text(u.fullName ?? u.email),
                    subtitle: Text('${u.email} • ${u.role ?? 'user'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: u.id == null
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                title: const Text('Delete user'),
                                content: const Text('Are you sure you want to delete this user?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                                ],
                              ));
                              if (ok == true && u.id != null) {
                                await _deleteUser(u.id!);
                              }
                            },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
