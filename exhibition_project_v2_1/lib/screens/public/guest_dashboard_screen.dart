import 'package:flutter/material.dart';

import '../exhibitor_exhibitions_screen.dart';
import '../login_screen.dart';

class GuestDashboardScreen extends StatelessWidget {
  const GuestDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest View'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Back to Login',
            icon: const Icon(Icons.login),
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
      body: const ExhibitorExhibitionsScreen(isGuest: true),
    );
  }
}
