import 'package:flutter/material.dart';
import '../models/exhibition.dart';
import '../services/database_service.dart';
import 'public/booth_map_screen.dart';
import 'floor_plan_viewer_screen.dart';

class ExhibitorExhibitionsScreen extends StatefulWidget {
  final bool isGuest;

  const ExhibitorExhibitionsScreen({super.key, this.isGuest = false});

  @override
  State<ExhibitorExhibitionsScreen> createState() =>
      _ExhibitorExhibitionsScreenState();
}

class _ExhibitorExhibitionsScreenState extends State<ExhibitorExhibitionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Exhibition> exhibitions = [];
  bool _isLoading = true;
  final Map<int, Map<String, dynamic>?> _floorPlanCache = {};
  String _searchQuery = '';

  Future<void> _openFloorPlan(Exhibition exhibition) async {
    final exhibitionId = exhibition.id;
    if (exhibitionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid exhibition.')),
      );
      return;
    }

    try {
      final floorPlan = await _dbService.getFloorPlanForExhibition(exhibitionId);
      if (!mounted) return;

      if (floorPlan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No floor plan uploaded for this exhibition yet.')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FloorPlanViewerScreen(
            exhibitionName: exhibition.name,
            floorPlan: floorPlan,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load floor plan: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExhibitions();
  }

  Future<void> _loadExhibitions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loadedExhibitions = await _dbService.getPublishedExhibitions();
      setState(() {
        exhibitions = loadedExhibitions;
        _floorPlanCache.clear();
        _isLoading = false;
      });
      print('DEBUG: Exhibitor loaded ${loadedExhibitions.length} exhibitions');
    } catch (e) {
      print('DEBUG: Error loading exhibitions: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exhibitions: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getFloorPlanForExhibitionCached(int exhibitionId) async {
    if (_floorPlanCache.containsKey(exhibitionId)) {
      return _floorPlanCache[exhibitionId];
    }
    final plan = await _dbService.getFloorPlanForExhibition(exhibitionId);
    _floorPlanCache[exhibitionId] = plan;
    return plan;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = exhibitions.where((e) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.status.toLowerCase().contains(q);
    }).toList();

    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          )
        : exhibitions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No exhibitions available',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new exhibitions',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search exhibitions',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _searchQuery = v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matches found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildExhibitionCard(filtered[index]);
                            },
                          ),
                  ),
                ],
              );
  }

  Widget _buildExhibitionCard(Exhibition exhibition) {
    final exhibitionId = exhibition.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exhibition.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exhibition.startDate} - ${exhibition.endDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: exhibition.status == 'Active'
                      ? Colors.green.withOpacity(0.1)
                      : exhibition.status == 'Upcoming'
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  exhibition.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: exhibition.status == 'Active'
                        ? Colors.green
                        : exhibition.status == 'Upcoming'
                            ? Colors.orange
                            : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  exhibition.location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exhibition.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>?>(
            future: exhibitionId == null
                ? Future<Map<String, dynamic>?>.value(null)
                : _getFloorPlanForExhibitionCached(exhibitionId),
            builder: (context, snapshot) {
              final hasFloorPlan = snapshot.connectionState == ConnectionState.done && snapshot.data != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: hasFloorPlan ? () => _openFloorPlan(exhibition) : null,
                          child: const Text('View Floor Plan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BoothMapScreen(
                                  boothCount: exhibition.totalBooths,
                                  exhibitionName: exhibition.name,
                                  exhibitionId: exhibition.id,
                                  readOnly: widget.isGuest,
                                  eventStartDate: exhibition.startDate,
                                  eventEndDate: exhibition.endDate,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(widget.isGuest ? 'View Map' : 'Apply'),
                        ),
                      ),
                    ],
                  ),
                  if (snapshot.connectionState == ConnectionState.done && !hasFloorPlan)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Floor Plan has not been uploaded.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
