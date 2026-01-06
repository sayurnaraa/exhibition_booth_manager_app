import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/database_service.dart';
import '../../models/exhibition.dart';
import '../login_screen.dart';
import '../admin/bookings_overview_screen.dart';
import '../admin/booth_mapping_screen.dart';
import '../admin/manage_exhibitions_screen.dart';
import '../admin/user_management_screen.dart';
import '../organizer/manage_booth_types_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  int _totalUsers = 0;
  int _totalBooths = 0;
  int _exhibitions = 0;
  int _bookings = 0;
  bool _isLoading = true;
  int _activeExhibitions = 0;
  int _selectedMenuIndex = 0; // 0: dashboard, 1: floor plan, 2: booth mapping, 3: users, 4: bookings
  // Floor plan state loaded from DB
  bool _hasFloorPlan = false;
  int? _floorPlanId;
  Map<String, String> _floorPlan = {};
  List<Exhibition> _exhibitionsList = [];
  int? _selectedExhibitionId;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadFloorPlan();
    _loadExhibitionsList();
  }

  Future<void> _loadFloorPlan() async {
    try {
      final map = await _db.getFloorPlan();
      if (map != null) {
        setState(() {
          _hasFloorPlan = true;
          _floorPlanId = map['id'] as int?;
          _floorPlan = {
            'name': map['name'] ?? '',
            'resolution': map['resolution'] ?? '',
            'size': map['size'] ?? '',
            'uploadedBy': map['uploadedBy'] ?? '',
            'uploadedDate': map['uploadedDate'] ?? '',
            'filePath': map['filePath'] ?? '',
            'exhibitionId': map['exhibitionId']?.toString() ?? '',
          };
          if (map['exhibitionId'] != null) {
            _selectedExhibitionId = map['exhibitionId'] as int;
          }
        });
      }
    } catch (e) {
      print('ADMIN - Failed to load floor plan: $e');
    }
  }

  Future<void> _loadExhibitionsList() async {
    try {
      final exs = await _db.getAllExhibitions();
      setState(() {
        _exhibitionsList = exs;
        if (_exhibitionsList.isNotEmpty && _selectedExhibitionId == null) {
          _selectedExhibitionId = _exhibitionsList.first.id;
        }
      });
    } catch (e) {
      print('ADMIN - Failed to load exhibitions list: $e');
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final users = await _db.getAllUsers();
      final exs = await _db.getAllExhibitions();
      final apps = await _db.getAllBoothApplications();
      // Calculate total booths as sum of exhibition.totalBooths
      int totalBooths = exs.fold(0, (sum, e) => sum + e.totalBooths);

      // Bookings: only Pending or Approved (reserved or already assigned)
      final pendingCount = apps.where((a) => a.status == 'Pending').length;
      final approvedCount = apps.where((a) => a.status == 'Approved').length;
      final bookingCount = pendingCount + approvedCount;

      // Active exhibitions count
      final activeExhibitions = exs.where((e) => e.status == 'Active').length;

      // Debug prints to help diagnose why counts may be zero
      print('ADMIN - Loaded users: ${users.length}');
      if (users.isNotEmpty) print('ADMIN - First user: ${users.first.email} (${users.first.role})');
      print('ADMIN - Loaded exhibitions: ${exs.length}');
      if (exs.isNotEmpty) print('ADMIN - First exhibition: ${exs.first.name} (${exs.first.totalBooths} booths)');
      print('ADMIN - Loaded applications: ${apps.length}');

      setState(() {
        _totalUsers = users.length;
        _exhibitions = exs.length;
        _activeExhibitions = activeExhibitions;
        _bookings = bookingCount;
        _totalBooths = totalBooths;
        _isLoading = false;
      });
    } catch (e) {
      print('ADMIN - Failed to load stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildManagementTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Admin Module'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: _buildPhoneContents(context)),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneContents(BuildContext context) {
    if (_selectedMenuIndex == 1) return _buildFloorPlanUploadContents(context);
    return [
      // Top AppBar area
      Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.menu),
                SizedBox(width: 8),
                Text('Administrator Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),

      // Debug / actions row
      if (!_isLoading && _totalUsers == 0 && _exhibitions == 0 && _bookings == 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding sample data...')));
                  await _db.resetDatabase();
                  await _loadStats();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample data seeded')));
                },
                icon: const Icon(Icons.build),
                label: const Text('Seed sample data'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ),

      // Stats grid
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isLoading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Total Users', '$_totalUsers', 'Registered users'),
                  _buildStatCard('Total Booths', '$_totalBooths', 'Total booths across exhibitions'),
                  _buildStatCard('Exhibitions', '$_exhibitions', '$_activeExhibitions active'),
                  _buildStatCard('Bookings', '$_bookings', 'Pending + Approved'),
                ],
              ),
      ),

      const SizedBox(height: 8),

      // Management list
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Management', style: TextStyle(fontWeight: FontWeight.bold)))),
            _buildManagementTile(Icons.event, 'Exhibition Management', 'Create, edit, publish, and delete exhibitions', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageExhibitionsScreen())).then((_) => _loadStats());
            }),
            _buildManagementTile(Icons.map, 'Booth Mapping', 'Position booths on floor plan', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoothMappingScreen()));
            }),
            _buildManagementTile(Icons.store_mall_directory_outlined, 'Booth Types', 'Manage booth types and prices', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageBoothTypesScreen()));
            }),
            _buildManagementTile(Icons.people_alt_outlined, 'User Management', 'View and manage registered users', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserManagementScreen())).then((_) => _loadStats());
            }),
            _buildManagementTile(Icons.upload_file, 'Floor Plan Upload', 'Upload or replace an exhibition floor plan', () {
              setState(() {
                _selectedMenuIndex = 1;
              });
            }),
            _buildManagementTile(Icons.book_online, 'Booking Management', 'Review and manage booth bookings', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsOverviewScreen())).then((_) => _loadStats());
            }),
            const SizedBox(height: 12),
            // Dev helper: seed DB when everything is zero
            if (!_isLoading && _totalUsers == 0 && _exhibitions == 0 && _bookings == 0)
              ElevatedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding sample data...')));
                  await _db.resetDatabase();
                  await _loadStats();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample data seeded')));
                },
                icon: const Icon(Icons.build),
                label: const Text('Seed sample data (dev)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildFloorPlanUploadContents(BuildContext context) {
    return [
      // Title area
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedMenuIndex = 0;
                    });
                    _loadStats();
                  },
                ),
                const SizedBox(width: 8),
                const Text('Floor Plan Upload', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // Current floor plan card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                ),
                child: Center(
                  child: _hasFloorPlan
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, size: 48, color: Colors.grey),
                            const SizedBox(height: 6),
                            Text(_floorPlan['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${_floorPlan['resolution']} · ${_floorPlan['size']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [Icon(Icons.image_not_supported, size: 48, color: Colors.grey), SizedBox(height: 8), Text('No floor plan uploaded')],
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _replaceFloorPlan(context),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Replace'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteFloorPlan(context),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasFloorPlan)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text('Uploaded: ${_floorPlan['uploadedDate']} · By: ${_floorPlan['uploadedBy']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 18),

      // Upload new floor plan area
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload New Floor Plan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.upload_file, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('Click to upload floor plan', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 6),
                              const Text('PNG, JPG, PDF up to 10MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 12),
                              // Exhibition selector
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: DropdownButtonFormField<int>(
                                  value: _selectedExhibitionId,
                                  items: _exhibitionsList.map((e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name))).toList(),
                                  onChanged: (v) => setState(() => _selectedExhibitionId = v),
                                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                  hint: const Text('Select exhibition'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _browseFiles(context),
                                child: const Text('Browse Files'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade400)),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _replaceFloorPlan(BuildContext context) async {
    // Replace by picking a new file. If an existing plan exists, delete it first.
    try {
      if (_floorPlanId != null) {
        await _db.deleteFloorPlanById(_floorPlanId!);
      }
      await _browseFiles(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Replace failed: $e')));
    }
  }

  Future<void> _deleteFloorPlan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Floor Plan'),
        content: const Text('Are you sure you want to delete the current floor plan?'),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete'))],
      ),
    );
    if (confirmed ?? false) {
      try {
        if (_floorPlanId != null) await _db.deleteFloorPlanById(_floorPlanId!);
        setState(() {
          _hasFloorPlan = false;
          _floorPlan = {};
          _floorPlanId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Floor plan deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _browseFiles(BuildContext context) async {
    try {
      if (_selectedExhibitionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an exhibition before uploading')));
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes ?? (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) throw Exception('Failed to read selected file');

      final docs = await getApplicationDocumentsDirectory();
      final storedDir = Directory(path.join(docs.path, 'floor_plans'));
      if (!await storedDir.exists()) await storedDir.create(recursive: true);
      final destName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final destPath = path.join(storedDir.path, destName);
      final file = File(destPath);
      await file.writeAsBytes(bytes);

      // Build metadata
      final sizeStr = '${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB';
      final meta = {
        'name': picked.name,
        'filePath': destPath,
        'resolution': '',
        'size': sizeStr,
        'uploadedBy': _db.getCurrentUser()?.fullName ?? 'Admin User',
        'uploadedDate': DateTime.now().toIso8601String(),
        'exhibitionId': _selectedExhibitionId,
      };

      final id = await _db.saveFloorPlan(meta);
      setState(() {
        _hasFloorPlan = true;
        _floorPlanId = id;
        _floorPlan = {
          'name': meta['name'].toString(),
          'resolution': meta['resolution'].toString(),
          'size': meta['size'].toString(),
          'uploadedBy': meta['uploadedBy'].toString(),
          'uploadedDate': meta['uploadedDate'].toString(),
          'filePath': meta['filePath'].toString(),
          'exhibitionId': (meta['exhibitionId'] ?? '').toString(),
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Floor plan uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Widget _buildPhoneMockup() {
    return Container(
      width: 360,
      height: 720,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black87, width: 3),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: _buildPhoneContents(context)),
      ),
    );
  }
}
