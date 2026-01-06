import 'package:flutter/material.dart';

class BoothMapping extends StatefulWidget {
  const BoothMapping({super.key});

  @override
  State<BoothMapping> createState() => _BoothMappingState();
}

class _BoothMappingState extends State<BoothMapping> {
  // We'll store our booths here.
  // Offset represents the X,Y position relative to the top-left of the map.
  final List<BoothMarker> _booths = [
    BoothMarker(id: 'A1', position: const Offset(100, 100), color: Colors.blue),
    BoothMarker(id: 'B2', position: const Offset(250, 200), color: Colors.green),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booth Mapping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map Layout Saved!')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Toolbar area
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                const Text('Drag booths to position them.'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addNewBooth,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Booth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // 2. The Interactive Map Area
          Expanded(
            child: InteractiveViewer(
              // Boundary settings for zooming/panning
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(100),
              constrained: false, // Allows the child to be larger than the screen

              child: Stack(
                children: [
                  // A. The Floor Plan Background
                  // In a real app, use Image.network() or Image.asset()
                  Container(
                    width: 800,
                    height: 800,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      // Optional: Add a grid pattern background
                      image: const DecorationImage(
                        image: NetworkImage('https://via.placeholder.com/800x800.png?text=Floor+Plan+Image'),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                  ),

                  // B. The Draggable Booths
                  ..._booths.map((booth) {
                    return Positioned(
                      left: booth.position.dx,
                      top: booth.position.dy,
                      child: GestureDetector(
                        // Handle Dragging Logic
                        onPanUpdate: (details) {
                          setState(() {
                            // Update the specific booth's position
                            // We add the "delta" (change) of the drag to the current position
                            booth.position += details.delta;
                          });
                        },
                        onTap: () => _showBoothDetails(booth),
                        child: _buildBoothWidget(booth),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logic to add a new booth at a default position
  void _addNewBooth() {
    setState(() {
      _booths.add(
        BoothMarker(
            id: 'New',
            position: const Offset(50, 50), // Start at top left
            color: Colors.orange
        ),
      );
    });
  }

  // The visual look of the booth on the map
  Widget _buildBoothWidget(BoothMarker booth) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: booth.color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: Center(
        child: Text(
          booth.id,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Simple dialog to edit booth details
  void _showBoothDetails(BoothMarker booth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Booth: ${booth.id}'),
        content: const Text('Here you could change size, assign exhibitors, or delete this booth.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
              onPressed: () {
                setState(() {
                  _booths.remove(booth);
                });
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}

// Simple data model for the marker
class BoothMarker {
  String id;
  Offset position;
  Color color;

  BoothMarker({required this.id, required this.position, required this.color});
}