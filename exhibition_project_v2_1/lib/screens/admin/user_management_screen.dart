import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/login_user.dart';
import '../../services/database_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  String? _loadError;
  List<LoginUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final users = await _db.getAllUsers();
      users.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  List<LoginUser> get _filteredUsers {
    final q = _searchController.text.toLowerCase();
    return _users.where((u) {
      if (q.isEmpty) return true;
      final name = (u.fullName ?? '').toLowerCase();
      final email = u.email.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  int get _total => _users.length;
  int get _active => _users.length;
  int get _inactive => 0;

  String _displayName(LoginUser user) {
    final name = (user.fullName ?? '').trim();
    return name.isNotEmpty ? name : user.email;
  }

  String _roleLabel(String? role) {
    final r = (role ?? 'user').trim();
    if (r.isEmpty) return 'User';
    return r[0].toUpperCase() + r.substring(1);
  }

  Future<void> _editUser(LoginUser user) async {
    final nameController = TextEditingController(text: user.fullName ?? '');
    String selectedRole = (user.role ?? 'user').trim().isEmpty ? 'user' : (user.role ?? 'user').trim();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'organizer', child: Text('Organizer')),
                  DropdownMenuItem(value: 'exhibitor', child: Text('Exhibitor')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  selectedRole = v;
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Save')),
          ],
        );
      },
    );

    if (shouldSave != true) {
      nameController.dispose();
      return;
    }

    try {
      final updated = LoginUser(
        id: user.id,
        email: user.email,
        password: user.password,
        fullName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
        role: selectedRole,
        createdAt: user.createdAt,
      );
      await _db.updateUser(updated);
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _deleteUser(LoginUser user) async {
    final id = user.id;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Delete ${_displayName(user)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _db.deleteUser(id);
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
    }
  }

  Future<void> _registerAdmin() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Register New Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Create Admin')),
          ],
        );
      },
    );

    if (shouldCreate != true) {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      return;
    }

    final fullName = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email and password are required.')));
      return;
    }

    try {
      await _db.register(
        LoginUser(
          email: email,
          password: password,
          fullName: fullName.isEmpty ? null : fullName,
          role: 'admin',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin registered successfully.')));
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register admin: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Register new admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: _registerAdmin,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {
            // TODO: filter flow
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _summaryCard('Total', _total.toString())),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard('Active', _active.toString(), highlight: true)),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard('Inactive', _inactive.toString())),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildListBody(df)),
          ],
        ),
      ),
    );
  }

  Widget _buildListBody(DateFormat df) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load users'),
            const SizedBox(height: 8),
            Text(_loadError!, style: TextStyle(color: Colors.grey.shade700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _loadUsers, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      );
    }

    final users = _filteredUsers;
    if (users.isEmpty) {
      return const Center(child: Text('No registered users found'));
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final u = users[index];
          final name = _displayName(u);
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(_initials(name), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                _statusBadge(true),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(u.email, style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('ID: ${u.id ?? '-'}', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Role: ${_roleLabel(u.role)}', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 6),
                            Text(
                              'Joined: ${u.createdAt != null ? df.format(u.createdAt!) : '-'}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        onPressed: () => _editUser(u),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () => _deleteUser(u),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: highlight ? Colors.green.shade800 : Colors.black)),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? Colors.green : Colors.grey.shade400),
      ),
      child: Text(active ? 'Active' : 'Inactive', style: TextStyle(color: active ? Colors.green.shade600 : Colors.grey.shade700)),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
