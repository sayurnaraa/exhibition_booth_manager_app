import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/organizer/organizer_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/public/guest_dashboard_screen.dart';

void main() {
  runApp(const ExhibitionManagerApp());
}

class ExhibitionManagerApp extends StatelessWidget {
  const ExhibitionManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exhibition Booth Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const LoginScreen(), // Start at the Login screen
      routes: {
        '/dashboard': (context) {
          return const DashboardScreen();
        },
        '/organizer-dashboard': (context) {
          return const OrganizerDashboardScreen();
        },
        '/admin-dashboard': (context) {
          return const AdminDashboardScreen();
        },
        '/guest': (context) {
          return const GuestDashboardScreen();
        },
      },
    );
  }
}
 