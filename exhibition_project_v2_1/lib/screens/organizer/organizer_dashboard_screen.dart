import 'package:flutter/material.dart';
import '../../screens/login_screen.dart';
import '../../services/database_service.dart';
import 'manage_exhibitions_screen.dart';
import 'manage_booth_types_screen.dart';
import 'manage_add_ons_screen.dart';
import 'approve_applications_screen.dart';
import '../admin/booth_mapping_screen.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  final DatabaseService _db = DatabaseService();

  int activeExhibitions = 0;
  int pendingReviews = 0;
  int totalBooths = 0;
  int approvedToday = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverviewStats();
  }

  Future<void> _loadOverviewStats() async {
    setState(() => _statsLoading = true);
    try {
      final active = await _db.getExhibitionsCountByStatus('Active');
      final pending = await _db.getBoothApplicationsCountByStatus('Pending');
      final booths = await _db.getTotalBoothsCount();
      final approved = await _db.getApprovedApplicationsCreatedTodayCount();
      if (!mounted) return;
      setState(() {
        activeExhibitions = active;
        pendingReviews = pending;
        totalBooths = booths;
        approvedToday = approved;
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () {
              // Explicitly navigate to the Login screen and remove other routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome, Event Organizer!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your exhibitions and booths',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Section
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildStatCard(
                  title: 'Active Exhibitions',
                  value: _statsLoading ? '...' : activeExhibitions.toString(),
                  icon: Icons.event_available,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'Pending Reviews',
                  value: _statsLoading ? '...' : pendingReviews.toString(),
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'Total Booths',
                  value: _statsLoading ? '...' : totalBooths.toString(),
                  icon: Icons.shop,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'Approved Today',
                  value: _statsLoading ? '...' : approvedToday.toString(),
                  icon: Icons.check_circle,
                  color: Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Management Section
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Management Options
            _buildManagementOption(
              title: 'Manage Exhibitions',
              subtitle: 'Create, edit, and manage exhibitions',
              icon: Icons.event_note,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageExhibitionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildManagementOption(
              title: 'Manage Booth Types',
              subtitle: 'Configure booth categories and pricing',
              icon: Icons.category,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageBoothTypesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildManagementOption(
              title: 'Manage Add-ons',
              subtitle: 'Configure booking add-ons for exhibitors',
              icon: Icons.add_box,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ManageAddOnsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildManagementOption(
              title: 'Booth Mapping',
              subtitle: 'Create and edit booth layouts',
              icon: Icons.map,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BoothMappingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildManagementOption(
              title: 'Approve Applications',
              subtitle: 'Review and approve booth applications',
              icon: Icons.assignment_turned_in,
              color: Colors.deepPurple,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ApproveApplicationsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOption({
    required String title,
    required String subtitle,
    required IconData icon,
    Color color = Colors.blue,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
