// lib/screens/public/booth_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/booth_application.dart';

enum BoothStatus { available, occupied, reserved }

class MapBooth {
  final String id;
  final String label;
  final String type;
  final Rect rect;
  final BoothStatus status;
  final String? exhibitorName;
  final double price;

  MapBooth({
    required this.id,
    required this.label,
    required this.type,
    required this.rect,
    required this.status,
    this.exhibitorName,
    required this.price,
  });
}

class BoothMapScreen extends StatefulWidget {
  final String? highlightBoothId;
  final int? boothCount;
  final String? exhibitionName;
  final int? exhibitionId;
  final bool readOnly;
  final String? eventStartDate;
  final String? eventEndDate;

  const BoothMapScreen({
    super.key,
    this.highlightBoothId,
    this.boothCount,
    this.exhibitionName,
    this.exhibitionId,
    this.readOnly = false,
    this.eventStartDate,
    this.eventEndDate,
  });

  @override
  State<BoothMapScreen> createState() => _BoothMapScreenState();
}

class _BoothMapScreenState extends State<BoothMapScreen> {
  late List<MapBooth> _booths;
  late double _canvasSize;
  MapBooth? _selectedBooth;
  final DatabaseService _dbService = DatabaseService();
  Map<String, List<String>> _boothAmenitiesById = {};
  List<String> _industryCategories = <String>[];
  final Map<String, double> _boothTypePriceByName = <String, double>{};
  List<String> _addOnOptions = <String>[];
  final Map<String, String> _addOnPriceByName = <String, String>{};

  static const List<String> _defaultIndustryCategories = <String>[
    'Food',
    'Coffee',
    'Telecom',
    'Technology',
    'Retail',
  ];

  static const double _adminCanvasBaseSize = 360.0;

  bool _rangesOverlap(double aStart, double aEnd, double bStart, double bEnd) {
    return (aEnd > bStart) && (bEnd > aStart);
  }

  bool _rectsAdjacent(Rect a, Rect b, {double gap = 0.5}) {
    // Treat "adjacent" as sharing an edge (within a small gap) with overlap
    // on the perpendicular axis.
    final leftTouch = (a.right - b.left).abs() <= gap && _rangesOverlap(a.top, a.bottom, b.top, b.bottom);
    final rightTouch = (b.right - a.left).abs() <= gap && _rangesOverlap(a.top, a.bottom, b.top, b.bottom);
    final topTouch = (a.bottom - b.top).abs() <= gap && _rangesOverlap(a.left, a.right, b.left, b.right);
    final bottomTouch = (b.bottom - a.top).abs() <= gap && _rangesOverlap(a.left, a.right, b.left, b.right);
    return leftTouch || rightTouch || topTouch || bottomTouch;
  }

  String _normalizeCompanyKey(String raw) {
    return raw.trim().toLowerCase();
  }

  String _normalizeCategoryKey(String raw) {
    return raw.trim().toLowerCase();
  }

  Future<String?> _adjacentCompetitorBlockReason({
    required MapBooth selectedBooth,
    required String selectingCompany,
    required String selectingCategory,
  }) async {
    if (widget.exhibitionId == null) return null;
    final exhibition = await _dbService.getExhibitionById(widget.exhibitionId!);
    if (exhibition == null || !exhibition.blockAdjacentCompetitors) return null;

    final selectingKey = _normalizeCompanyKey(selectingCompany);
    final selectingCategoryKey = _normalizeCategoryKey(selectingCategory);
    if (selectingCategoryKey.isEmpty) {
      return 'Industry/category is required when the adjacency rule is enabled.';
    }
    if (selectingKey.isEmpty) {
      return 'Company name is required when the adjacency rule is enabled.';
    }

    // Build boothId -> (status, companyName) using priority Approved > Pending.
    final apps = await _dbService.getBoothApplicationsByExhibition(widget.exhibitionId!);
    final Map<String, String> boothStatus = {};
    final Map<String, String> boothCompany = {};
    final Map<String, String> boothCategory = {};

    int priority(String s) {
      if (s == 'Approved') return 2;
      if (s == 'Pending') return 1;
      return 0;
    }

    for (final app in apps) {
      final bid = _normalizeBoothId(app.boothId);
      final st = app.status;
      if (priority(st) == 0) continue;

      final current = boothStatus[bid];
      if (current != null && priority(current) >= priority(st)) continue;

      boothStatus[bid] = st;
      boothCompany[bid] = app.companyName;
      boothCategory[bid] = app.industryCategory;
    }

    final selectedRect = selectedBooth.rect;
    for (final other in _booths) {
      if (other.id == selectedBooth.id) continue;
      final bid = _normalizeBoothId(other.id);
      final st = boothStatus[bid];
      if (st == null) continue;
      if (!_rectsAdjacent(selectedRect, other.rect)) continue;

      final otherCompanyKey = _normalizeCompanyKey(boothCompany[bid] ?? '');
      final otherCategoryKey = _normalizeCategoryKey(boothCategory[bid] ?? '');
      if (otherCompanyKey.isEmpty) continue;
      if (otherCategoryKey.isEmpty) continue;
      // Only block adjacency for same industry/category (competitors)
      if (otherCategoryKey != selectingCategoryKey) continue;
      if (otherCompanyKey == selectingKey) continue;

      return 'Cannot book Booth ${selectedBooth.label}: it is adjacent to Booth ${other.label} (${st.toLowerCase()}) by another company.';
    }

    return null;
  }

  DateTime? _tryParseEventDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    // Try ISO first
    final iso = DateTime.tryParse(v);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // Common human-readable formats used in this app's sample data.
    for (final f in <DateFormat>[DateFormat('d MMM yyyy'), DateFormat('dd MMM yyyy')]) {
      try {
        final dt = f.parseLoose(v);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {
        // continue
      }
    }
    return null;
  }

  String _formatDateYmd(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  int _inclusiveDays(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  Future<void> _loadExhibitionCategories() async {
    if (widget.exhibitionId == null) return;
    try {
      final ex = await _dbService.getExhibitionById(widget.exhibitionId!);
      if (!mounted) return;
      setState(() {
        final fromDb = (ex?.industryCategories ?? const <String>[])
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _industryCategories = fromDb.isNotEmpty ? fromDb : _defaultIndustryCategories;
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  void initState() {
    super.initState();
    // Canvas size will be set based on screen dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _recalculateCanvasSize();
      await _loadBoothTypes();
      await _loadAddOns();
      await _loadExhibitionCategories();
      await _loadMapData();
    });
    _booths = [];
  }

  Future<void> _loadAddOns() async {
    try {
      final exhibitionId = widget.exhibitionId;
      if (exhibitionId == null) {
        if (!mounted) return;
        setState(() {
          _addOnOptions = <String>[];
          _addOnPriceByName.clear();
        });
        return;
      }

      final rows = await _dbService.getAddOnsForExhibition(exhibitionId);
      final names = <String>[];
      final prices = <String, String>{};
      for (final r in rows) {
        final name = (r['name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        names.add(name);
        final price = (r['price']?.toString() ?? '').trim();
        if (price.isNotEmpty) {
          prices[name] = price;
        }
      }
      if (!mounted) return;
      setState(() {
        _addOnOptions = names;
        _addOnPriceByName
          ..clear()
          ..addAll(prices);
      });
    } catch (_) {
      // ignore
    }
  }

  double _parsePriceToDouble(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.trim().isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _loadBoothTypes() async {
    try {
      final types = await _dbService.getBoothTypes();
      final map = <String, double>{};
      for (final t in types) {
        final name = t['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final priceRaw = t['price']?.toString() ?? '';
        final price = _parsePriceToDouble(priceRaw);
        if (price > 0) {
          map[name] = price;
        }
      }
      if (!mounted) return;
      setState(() {
        _boothTypePriceByName
          ..clear()
          ..addAll(map);
      });
    } catch (_) {
      // ignore
    }
  }

  double _priceForType(String typeName) {
    final key = typeName.trim();
    if (key.isEmpty) return 1500.0;
    final found = _boothTypePriceByName[key];
    return (found != null && found > 0) ? found : 1500.0;
  }

  String _normalizeBoothId(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  }

  List<MapBooth> _generateBoothsFromSavedLayout(List<Map<String, dynamic>> layout) {
    final double scale = _canvasSize / _adminCanvasBaseSize;
    final List<MapBooth> booths = [];

    for (final b in layout) {
      final rawNumber = (b['number']?.toString() ?? b['id']?.toString() ?? '').trim();
      final id = _normalizeBoothId(rawNumber.isNotEmpty ? rawNumber : 'B00');

      final left = (b['left'] as num?)?.toDouble() ?? 40.0;
      final top = (b['top'] as num?)?.toDouble() ?? 40.0;
      final width = (b['width'] as num?)?.toDouble() ?? 64.0;
      final height = (b['height'] as num?)?.toDouble() ?? 64.0;
      final type = (b['type']?.toString() ?? 'Standard').trim();
      final effectiveType = type.isEmpty ? 'Standard' : type;

      booths.add(
        MapBooth(
          id: id,
          label: id,
          type: effectiveType,
          rect: Rect.fromLTWH(left * scale, top * scale, width * scale, height * scale),
          status: BoothStatus.available,
          price: _priceForType(effectiveType),
          exhibitorName: null,
        ),
      );
    }

    return booths;
  }

  Future<void> _loadMapData() async {
    // Load booth layout first (override > default), then apply booth applications statuses.
    List<MapBooth> baseBooths;

    if (widget.exhibitionId != null) {
      try {
        final layout = await _dbService.getEffectiveBoothLayout(widget.exhibitionId!);
        if (layout.isNotEmpty) {
          baseBooths = _generateBoothsFromSavedLayout(layout);
        } else {
          baseBooths = _generateGridBooths();
        }
      } catch (_) {
        baseBooths = _generateGridBooths();
      }
    } else {
      baseBooths = _generateGridBooths();
    }

    setState(() {
      _booths = baseBooths;
    });

    await _loadApplicationsFromDb(baseBooths: baseBooths);
  }

  Future<void> _loadApplicationsFromDb({required List<MapBooth> baseBooths}) async {
    if (widget.exhibitionId == null) return;
    try {
      final apps = await _dbService.getBoothApplicationsByExhibition(widget.exhibitionId!);

      // Map of boothId -> highest-priority status (Approved > Pending)
      final Map<String, String> boothStatusMap = {};
      final Map<String, String?> boothExhibitorMap = {};
      final Map<String, List<String>> boothAmenitiesMap = {};

      for (final app in apps) {
        final bid = _normalizeBoothId(app.boothId);
        final st = app.status;
        // Approved overrides pending
        if (boothStatusMap[bid] == 'Approved') continue;
        boothStatusMap[bid] = st;
        boothExhibitorMap[bid] = app.exhibitorName;

        final normalizedAmenities = app.addItems
            .map(_normalizeAmenityLabel)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        boothAmenitiesMap[bid] = normalizedAmenities;
      }

      // Apply statuses to generated booths
      final List<MapBooth> updated = baseBooths.map((b) {
        final s = boothStatusMap[_normalizeBoothId(b.id)];
        if (s == 'Approved') {
          return MapBooth(id: b.id, label: b.label, type: b.type, rect: b.rect, status: BoothStatus.occupied, exhibitorName: boothExhibitorMap[_normalizeBoothId(b.id)], price: b.price);
        } else if (s == 'Pending') {
          return MapBooth(id: b.id, label: b.label, type: b.type, rect: b.rect, status: BoothStatus.reserved, exhibitorName: boothExhibitorMap[_normalizeBoothId(b.id)], price: b.price);
        }
        return b;
      }).toList();

      setState(() {
        _booths = updated;
        _boothAmenitiesById = boothAmenitiesMap;
      });
    } catch (e) {
      print('DATABASE - Failed to load booth applications for map: $e');
    }
  }

  String _normalizeAmenityLabel(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    switch (v.toLowerCase()) {
      case 'extended wifi':
      case 'wifi':
        return 'WiFi';
      case 'additional furniture':
      case 'furniture':
        return 'Furniture';
      case 'promotional spot':
        return 'Promotional Spot';
      default:
        return v;
    }
  }

  List<String> _amenitiesForBooth(MapBooth booth) {
    // Simple default amenities for every booth; add-ons come from applications.
    final base = <String>['WiFi', 'Furniture'];
    final fromApp = _boothAmenitiesById[_normalizeBoothId(booth.id)] ?? const <String>[];
    final all = <String>{...base, ...fromApp}.toList()..sort();
    return all;
  }

  void _recalculateCanvasSize() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarHeight = kToolbarHeight;
    final legendHeight = 50.0; // approximate height of legend
    
    // Calculate available space for the map
    final availableHeight = screenHeight - appBarHeight - legendHeight - MediaQuery.of(context).padding.top - 50;
    final availableWidth = screenWidth - 20; // 10px margin on each side
    
    // Make canvas square and fit within available space
    _canvasSize = availableHeight < availableWidth ? availableHeight : availableWidth;
  }

  // --- HELPER: GENERATE TIGHTER GRID ---
  List<MapBooth> _generateGridBooths() {
    List<MapBooth> booths = [];
    
    // Use provided booth count or default to 12
    int targetBoothCount = widget.boothCount ?? 12;
    
    // Calculate grid layout (roughly square, e.g., 3x4 for 12 booths)
    int cols = (targetBoothCount / 4).ceil();
    if (cols > 5) cols = 5;
    int rows = (targetBoothCount / cols).ceil();
    
    // Use responsive canvas size
    double canvasSize = _canvasSize;

    // Booth Size (smaller)
    double boothW = 60;
    double boothH = 50;
    double gap = 10.0;
    
    // If layout is too large, scale down booths further
    final double totalGridWidth = (cols * boothW) + ((cols - 1) * gap);
    if (totalGridWidth > canvasSize) {
      double scale = canvasSize / totalGridWidth * 0.95; // 95% to leave margin
      boothW *= scale;
      boothH *= scale;
      gap *= scale;
    }

    // Calculate total width/height of the grid block to center it
    final double newTotalGridWidth = (cols * boothW) + ((cols - 1) * gap);
    final double newTotalGridHeight = (rows * boothH) + ((rows - 1) * gap);

    // Calculate starting X and Y to CENTER the grid on the canvas
    final double startX = (canvasSize - newTotalGridWidth) / 2;
    final double startY = (canvasSize - newTotalGridHeight) / 2;

    int idCounter = 1;

    for (int r = 0; r < rows && idCounter <= targetBoothCount; r++) {
      for (int c = 0; c < cols && idCounter <= targetBoothCount; c++) {
        final double left = startX + c * (boothW + gap);
        final double top = startY + r * (boothH + gap);

        String id = 'B${idCounter.toString().padLeft(2, '0')}';

        BoothStatus status = BoothStatus.available;
        String? exhibitor;
        if (idCounter % 3 == 0) {
          status = BoothStatus.occupied;
          exhibitor = 'Exhibitor $idCounter';
        } else if (idCounter % 5 == 0) {
          status = BoothStatus.reserved;
        }

        const defaultType = 'Standard';
        booths.add(MapBooth(
          id: id,
          label: id,
          type: defaultType,
          rect: Rect.fromLTWH(left, top, boothW, boothH),
          status: status,
          price: _priceForType(defaultType),
          exhibitorName: exhibitor,
        ));
        idCounter++;
      }
    }
    return booths;
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exhibitionName ?? 'Exhibition Floor Map'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (widget.highlightBoothId != null)
            Container(
              width: double.infinity,
              color: Colors.yellow.shade700,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Highlighting Booth: ${widget.highlightBoothId}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0,2))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Available', Colors.green),
                _buildLegendItem('Occupied', Colors.red.shade300),
                _buildLegendItem('Reserved', Colors.orange),
              ],
            ),
          ),

          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(50),
              constrained: false,
              child: Stack(
                children: [
                  // 1. Floor Background
                  Container(
                    width: _canvasSize,
                    height: _canvasSize,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                    ),
                  ),

                  // 2. NEW: ENTRANCE (Top Center)
                  Positioned(
                    top: 0,
                    left: (_canvasSize - 150) / 2,
                    child: _buildDoorMarker('ENTRANCE', Colors.green.shade600, Icons.login),
                  ),

                  // 3. NEW: EXIT (Bottom Center)
                  Positioned(
                    bottom: 0,
                    left: (_canvasSize - 150) / 2,
                    child: _buildDoorMarker('EXIT', Colors.red.shade600, Icons.logout),
                  ),

                  // 4. Draw Booths
                  ..._booths.map((booth) => _buildBoothWidget(booth)).toList(),
                ],
              ),
            ),
          ),

          // Legend and Selected Booth Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Column(
              children: [
                // Legend Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem('Available', Colors.green.shade600),
                      _buildLegendItem('Occupied', Colors.red.shade400),
                      _buildLegendItem('Reserved', Colors.orange.shade400),
                      _buildLegendItem('Selected', Colors.blue.shade600),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Selected Booth Info
                if (_selectedBooth != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Selected: Booth ${_selectedBooth!.label} - ${_selectedBooth!.status.name.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  )
                else
                  Text(
                    'Tap a booth to select',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW Helper for Doors ---
  Widget _buildDoorMarker(String label, Color color, IconData icon) {
    return Container(
      width: 150,
      height: 40,
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border(
            // Show border only on the "inside" edge
            bottom: label == 'ENTRANCE' ? BorderSide(color: color, width: 3) : BorderSide.none,
            top: label == 'EXIT' ? BorderSide(color: color, width: 3) : BorderSide.none,
          )
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2)
          ),
        ],
      ),
    );
  }

  Widget _buildBoothWidget(MapBooth booth) {
    Color color;
    bool isHighlighted = widget.highlightBoothId == booth.id;
    bool isSelected = _selectedBooth?.id == booth.id;

    if (isSelected) {
      color = Colors.blue.shade600;
    } else if (isHighlighted) {
      color = Colors.yellow.shade700;
    } else {
      switch (booth.status) {
        case BoothStatus.available: color = Colors.green.shade600; break;
        case BoothStatus.occupied: color = Colors.red.shade400; break;
        case BoothStatus.reserved: color = Colors.orange.shade400; break;
      }
    }

    return Positioned(
      left: booth.rect.left,
      top: booth.rect.top,
      width: booth.rect.width,
      height: booth.rect.height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedBooth = (_selectedBooth?.id == booth.id) ? null : booth;
          });
          if (_selectedBooth != null) {
            _showBoothInfo(booth);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected || isHighlighted ? 1.0 : 0.9),
            border: Border.all(
                color: isSelected ? Colors.blue : isHighlighted ? Colors.black : Colors.white.withOpacity(0.5),
                width: isSelected ? 3 : isHighlighted ? 3 : 1.5
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (!isSelected && !isHighlighted)
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              if (isSelected || isHighlighted)
                BoxShadow(color: isSelected ? Colors.blue.withOpacity(0.5) : Colors.yellow.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
            ],
          ),
          child: Center(
            child: Text(
              booth.label,
              style: TextStyle(
                color: isSelected || isHighlighted ? Colors.white : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBoothInfo(MapBooth booth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = (screenHeight * 0.6).clamp(280.0, screenHeight * 0.9).toDouble();

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            height: sheetHeight,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Booth ${booth.label}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Type: ${booth.type}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(
                        booth.status.name.toUpperCase(),
                        style: TextStyle(color: _getStatusColor(booth.status), fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _getStatusColor(booth.status).withOpacity(0.1),
                    )
                  ],
                ),
                const Divider(height: 30),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (booth.status == BoothStatus.occupied) ...[
                          const Text('Current Exhibitor:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(booth.exhibitorName ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          const Text('Amenities:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _amenitiesForBooth(booth)
                                .map(
                                  (a) => Chip(
                                    label: Text(a, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                    labelStyle: const TextStyle(color: Colors.blue),
                                  ),
                                )
                                .toList(),
                          ),
                        ] else if (booth.status == BoothStatus.available) ...[
                          Row(
                            children: [
                              const Icon(Icons.aspect_ratio, color: Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Text('${booth.rect.width.toStringAsFixed(0)}m x ${booth.rect.height.toStringAsFixed(0)}m', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Amenities:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _amenitiesForBooth(booth)
                                .map(
                                  (a) => Chip(
                                    label: Text(a, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                    labelStyle: const TextStyle(color: Colors.blue),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Price: ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(booth.price)}',
                            style: TextStyle(fontSize: 24, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                          ),
                        ] else ...[
                          const Text('This booth is currently reserved.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
                          const SizedBox(height: 12),
                          const Text('Amenities:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _amenitiesForBooth(booth)
                                .map(
                                  (a) => Chip(
                                    label: Text(a, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                    labelStyle: const TextStyle(color: Colors.blue),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (booth.status == BoothStatus.available && widget.readOnly)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Login to book a booth. Guest mode is view-only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                else if (booth.status == BoothStatus.available)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (widget.exhibitionId != null && _industryCategories.isEmpty) {
                          await _loadExhibitionCategories();
                        }
                        // Prompt for contact details then save application
                        await showDialog<void>(
                          context: context,
                          builder: (dialogContext) {
                            final formKey = GlobalKey<FormState>();
                            final nameController = TextEditingController();
                            final companyController = TextEditingController();
                            final companyDescController = TextEditingController();
                            final exhibitProfileController = TextEditingController();
                            final emailController = TextEditingController();
                            final phoneController = TextEditingController();

                            final addOnOptions = _addOnOptions.isNotEmpty
                                ? _addOnOptions
                                : const <String>[
                                    'Additional furniture',
                                    'Promotional spot',
                                    'Extended WiFi',
                                  ];
                            final Map<String, bool> addOns = {
                              for (final a in addOnOptions) a: false,
                            };

                            final eventStart = _tryParseEventDate(widget.eventStartDate ?? '');
                            final eventEnd = _tryParseEventDate(widget.eventEndDate ?? '');

                            DateTimeRange? bookingRange;
                            if (eventStart != null && eventEnd != null && !eventEnd.isBefore(eventStart)) {
                              bookingRange = DateTimeRange(start: eventStart, end: eventEnd);
                            }

                            final dropdownCategories = _industryCategories.isNotEmpty
                                ? _industryCategories
                                : const <String>['Other'];
                            String selectedCategory = dropdownCategories.first;

                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                                Future<void> pickBookingRange() async {
                                  if (eventStart == null || eventEnd == null) return;

                                  final initialRange = bookingRange ?? DateTimeRange(start: eventStart, end: eventEnd);
                                  final picked = await showDateRangePicker(
                                    context: dialogContext,
                                    firstDate: eventStart,
                                    lastDate: eventEnd,
                                    initialDateRange: initialRange,
                                    helpText: 'Select booking dates (within event)',
                                  );
                                  if (picked == null) return;
                                  setDialogState(() {
                                    bookingRange = picked;
                                  });
                                }

                                return Padding(
                                  padding: EdgeInsets.only(bottom: bottomInset),
                                  child: AlertDialog(
                                    scrollable: true,
                                    title: Text('Book Booth ${booth.label}'),
                                    content: Form(
                                      key: formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (eventStart != null && eventEnd != null && !eventEnd.isBefore(eventStart)) ...[
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text('Booking period'),
                                              subtitle: Text(
                                                (() {
                                                  final effectiveRange = bookingRange ?? DateTimeRange(start: eventStart, end: eventEnd);
                                                  return '${_formatDateYmd(effectiveRange.start)} → ${_formatDateYmd(effectiveRange.end)} '
                                                      '(${_inclusiveDays(effectiveRange.start, effectiveRange.end)} days)';
                                                })(),
                                              ),
                                              trailing: const Icon(Icons.date_range),
                                              onTap: pickBookingRange,
                                            ),
                                            const Divider(),
                                          ],
                                          TextFormField(
                                            controller: nameController,
                                            decoration: const InputDecoration(labelText: 'Contact Name'),
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                                          ),
                                          TextFormField(
                                            controller: companyController,
                                            decoration: const InputDecoration(labelText: 'Company Name'),
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter company name' : null,
                                          ),
                                          DropdownButtonFormField<String>(
                                            value: selectedCategory,
                                            decoration: const InputDecoration(labelText: 'Industry/Category'),
                                            items: dropdownCategories
                                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                                .toList(),
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Select a category' : null,
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setDialogState(() {
                                                selectedCategory = v;
                                              });
                                            },
                                          ),
                                          TextFormField(
                                            controller: companyDescController,
                                            decoration: const InputDecoration(labelText: 'Company Description'),
                                            maxLines: 2,
                                          ),
                                          TextFormField(
                                            controller: exhibitProfileController,
                                            decoration: const InputDecoration(labelText: 'Exhibit Profile/Description'),
                                            maxLines: 3,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter exhibit profile' : null,
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Add-ons',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                            ),
                                          ),
                                          ...addOns.entries.map((entry) {
                                            final price = _addOnPriceByName[entry.key];
                                            return CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              dense: true,
                                              title: Text(entry.key),
                                              subtitle: (price != null && price.trim().isNotEmpty) ? Text(price) : null,
                                              value: entry.value,
                                              onChanged: (v) {
                                                setDialogState(() {
                                                  addOns[entry.key] = v ?? false;
                                                });
                                              },
                                            );
                                          }).toList(),
                                          TextFormField(
                                            controller: emailController,
                                            decoration: const InputDecoration(labelText: 'Email'),
                                            keyboardType: TextInputType.emailAddress,
                                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                                          ),
                                          TextFormField(
                                            controller: phoneController,
                                            decoration: const InputDecoration(labelText: 'Phone'),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            validator: (v) {
                                              final value = (v ?? '').trim();
                                              if (value.isEmpty) return null;
                                              if (!RegExp(r'^\d+$').hasMatch(value)) {
                                                return 'Phone must be numbers only';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (!(formKey.currentState?.validate() ?? false)) return;

                                          final currentUser = _dbService.getCurrentUser();
                                          final selectedAddItems = addOns.entries
                                              .where((e) => e.value)
                                              .map((e) => e.key)
                                              .toList();

                                          final companyName = companyController.text.trim();
                                          final category = selectedCategory.trim();
                                          final blockReason = await _adjacentCompetitorBlockReason(
                                            selectedBooth: booth,
                                            selectingCompany: companyName,
                                            selectingCategory: category,
                                          );
                                          if (blockReason != null) {
                                            if (!dialogContext.mounted) return;
                                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                              SnackBar(content: Text(blockReason)),
                                            );
                                            return;
                                          }

                                          final application = BoothApplication(
                                            exhibitionId: widget.exhibitionId ?? 0,
                                            userId: currentUser?.id ?? 0,
                                            boothId: booth.id,
                                            exhibitorName: currentUser?.fullName ?? nameController.text.trim(),
                                            companyName: companyName,
                                            industryCategory: category,
                                            companyDescription: companyDescController.text.trim(),
                                            exhibitProfile: exhibitProfileController.text.trim(),
                                            addItems: selectedAddItems,
                                            eventStartDate: widget.eventStartDate ?? '',
                                            eventEndDate: widget.eventEndDate ?? '',
                                            bookingStartDate: bookingRange != null ? _formatDateYmd(bookingRange!.start) : '',
                                            bookingEndDate: bookingRange != null ? _formatDateYmd(bookingRange!.end) : '',
                                            email: currentUser?.email ?? emailController.text.trim(),
                                            phone: phoneController.text.trim(),
                                            createdAt: DateTime.now().toIso8601String(),
                                          );

                                          try {
                                            final created = await _dbService.createBoothApplication(application);
                                            if (!mounted) return;

                                            Navigator.of(dialogContext).pop();
                                            setState(() {
                                              _booths = _booths.map((b) {
                                                if (b.id == booth.id) {
                                                  return MapBooth(
                                                    id: b.id,
                                                    label: b.label,
                                                    type: b.type,
                                                    rect: b.rect,
                                                    status: BoothStatus.reserved,
                                                    exhibitorName: created.exhibitorName,
                                                    price: b.price,
                                                  );
                                                }
                                                return b;
                                              }).toList();

                                              _boothAmenitiesById[_normalizeBoothId(booth.id)] = selectedAddItems
                                                  .map(_normalizeAmenityLabel)
                                                  .where((s) => s.isNotEmpty)
                                                  .toSet()
                                                  .toList()
                                                ..sort();
                                            });

                                            await _loadMapData();
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(this.context).showSnackBar(
                                              SnackBar(content: Text('Application submitted for Booth ${booth.label}')),
                                            );
                                          } catch (e) {
                                            if (!dialogContext.mounted) return;
                                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                              SnackBar(content: Text('Failed to submit application: $e')),
                                            );
                                          }
                                        },
                                        child: const Text('Submit Application'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('BOOK BOOTH'),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _getStatusColor(BoothStatus status) {
    switch (status) {
      case BoothStatus.available:
        return Colors.green.shade600;
      case BoothStatus.occupied:
        return Colors.red.shade400;
      case BoothStatus.reserved:
        return Colors.orange.shade400;
    }
  }

}
