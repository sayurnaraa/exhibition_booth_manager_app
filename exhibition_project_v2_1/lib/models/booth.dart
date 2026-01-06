// lib/models/booth.dart
class Booth {
  final String id;
  final String name;
  final String exhibitor;
  final String status; // e.g., 'Occupied', 'Available', 'Maintenance'
  final int leadsCount;

  const Booth({
    required this.id,
    required this.name,
    required this.exhibitor,
    required this.status,
    required this.leadsCount,
  });
}

// Mock Data for the List View
List<Booth> mockBooths = [
  const Booth(id: 'A01', name: 'Tech Showcase', exhibitor: 'Innovate Solutions', status: 'Occupied', leadsCount: 45),
  const Booth(id: 'B05', name: 'Food Zone', exhibitor: 'Gourmet Foods Ltd', status: 'Available', leadsCount: 0),
  const Booth(id: 'C12', name: 'Auto Demo', exhibitor: 'Global Motors', status: 'Maintenance', leadsCount: 12),
  const Booth(id: 'D03', name: 'Startup Alley', exhibitor: 'Future Tech', status: 'Occupied', leadsCount: 98),
];