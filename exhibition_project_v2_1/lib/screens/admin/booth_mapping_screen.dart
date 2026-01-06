import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import '../../services/database_service.dart';
import '../../models/exhibition.dart';

class BoothMappingScreen extends StatefulWidget {
  const BoothMappingScreen({super.key});

  @override
  State<BoothMappingScreen> createState() => _BoothMappingScreenState();
}

class _BoothMappingScreenState extends State<BoothMappingScreen> {
  int _nextId = 1;
  int? _selectedBoothId;

  // booth model: id, number, type, left, top
  final List<Map<String, dynamic>> _booths = [];
  final DatabaseService _db = DatabaseService();
  List<Exhibition> _exhibitions = [];
  int? _selectedExhibitionId;

  Map<String, dynamic>? _floorPlan;

  List<String> _boothTypeNames = [];

  List<String> get _effectiveBoothTypeNames {
    final out = <String>[];
    void addUnique(String v) {
      final value = v.trim();
      if (value.isEmpty) return;
      if (!out.contains(value)) out.add(value);
    }

    for (final t in _boothTypeNames) {
      addUnique(t);
    }
    // If no booth types exist yet, fall back to legacy defaults.
    if (out.isEmpty) {
      addUnique('Standard');
      addUnique('Premium');
      addUnique('Corner');
    }
    return out;
  }

  bool get _isAdmin {
    final role = (_db.getCurrentUser()?.role ?? 'admin').toLowerCase();
    return role == 'admin';
  }

  String get _saveScope => _isAdmin ? 'admin_override' : 'default';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadBoothTypes();
    await _loadExhibitions();
  }

  Future<void> _loadBoothTypes() async {
    final types = await _db.getBoothTypes();
    final names = types
        .map((t) => t['name']?.toString() ?? '')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (!mounted) return;
    setState(() {
      _boothTypeNames = names;
    });
  }

  void _addBooth() {
    final id = _nextId++;
    final defaultType = _effectiveBoothTypeNames.isNotEmpty ? _effectiveBoothTypeNames.first : 'Standard';
    setState(() {
      _booths.add({
        'id': id,
        'number': 'B-${id.toString().padLeft(2, '0')}',
        'type': defaultType,
        'left': 40.0 + (_booths.length * 70) % 220,
        'top': 40.0,
        'width': 64.0,
        'height': 64.0,
      });
      _selectedBoothId = id;
    });
  }

  void _removeSelected() {
    if (_selectedBoothId == null) return;
    setState(() {
      _booths.removeWhere((b) => b['id'] == _selectedBoothId);
      _selectedBoothId = null;
    });
  }

  Map<String, dynamic> _normalizeBooth(Map<String, dynamic> raw) {
    final id = (raw['id'] as num?)?.toInt() ?? _nextId++;
    final number = (raw['number']?.toString() ?? 'B-${id.toString().padLeft(2, '0')}');
    final fallbackType = _effectiveBoothTypeNames.isNotEmpty ? _effectiveBoothTypeNames.first : 'Standard';
    final type = (raw['type']?.toString() ?? fallbackType);
    final left = (raw['left'] as num?)?.toDouble() ?? 40.0;
    final top = (raw['top'] as num?)?.toDouble() ?? 40.0;
    final width = (raw['width'] as num?)?.toDouble() ?? 64.0;
    final height = (raw['height'] as num?)?.toDouble() ?? 64.0;
    return {
      'id': id,
      'number': number,
      'type': type,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  Future<void> _loadLayoutForSelectedExhibition() async {
    final exhibitionId = _selectedExhibitionId;
    if (exhibitionId == null) return;

    try {
      List<Map<String, dynamic>> loaded;
      if (_isAdmin) {
        loaded = await _db.getBoothLayout(exhibitionId, 'admin_override');
        if (loaded.isEmpty) {
          loaded = await _db.getBoothLayout(exhibitionId, 'default');
        }
      } else {
        loaded = await _db.getBoothLayout(exhibitionId, 'default');
      }

      int maxId = 0;
      final normalized = loaded.map(_normalizeBooth).toList();
      for (final b in normalized) {
        maxId = math.max(maxId, (b['id'] as int));
      }

      setState(() {
        _booths
          ..clear()
          ..addAll(normalized);
        _selectedBoothId = null;
        _nextId = math.max(1, maxId + 1);
      });

      // Load floor plan metadata for the selected exhibition (for background rendering).
      try {
        final plan = await _db.getFloorPlanForExhibition(exhibitionId);
        if (!mounted) return;
        setState(() {
          _floorPlan = plan;
        });
      } catch (_) {
        // ignore
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load booth layout: $e')));
    }
  }

  Widget _buildFloorPlanBackground() {
    final plan = _floorPlan;
    final filePath = (plan?['filePath']?.toString() ?? '').trim();
    if (filePath.isEmpty) return const SizedBox.shrink();
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('Floor plan is a PDF (background preview disabled).'),
      );
    }

    final f = File(filePath);
    return FutureBuilder<bool>(
      future: f.exists(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(color: Colors.grey.shade200);
        }
        if (snap.data != true) {
          return Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('Floor plan file not found.'),
          );
        }
        return Image.file(
          f,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Future<void> _saveLayout() async {
    final exhibitionId = _selectedExhibitionId;
    if (exhibitionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an exhibition first.')));
      return;
    }

    try {
      final payload = _booths.map((b) => _normalizeBooth(Map<String, dynamic>.from(b))).toList();
      await _db.upsertBoothLayout(exhibitionId: exhibitionId, scope: _saveScope, booths: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isAdmin ? 'Admin override layout saved.' : 'Default layout saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save booth layout: $e')));
    }
  }

  Map<String, dynamic>? get _selectedBooth {
    if (_selectedBoothId == null) return null;
    try {
      return _booths.firstWhere((b) => b['id'] == _selectedBoothId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBooth = _selectedBooth;
    final boothTypeOptions = List<String>.from(_effectiveBoothTypeNames);
    final selectedType = selectedBooth?['type']?.toString().trim();
    if (selectedType != null && selectedType.isNotEmpty && !boothTypeOptions.contains(selectedType)) {
      boothTypeOptions.insert(0, selectedType);
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Booth Mapping'),
        backgroundColor: Colors.deepPurple,
        actions: [
          TextButton.icon(
            onPressed: _saveLayout,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: const [Icon(Icons.open_with), SizedBox(width: 8), Text('Drag booths to reposition on floor plan')]),
              ),

              const SizedBox(height: 12),

              // Canvas + Add Booth button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                              const Text('Floor Plan Canvas', style: TextStyle(fontWeight: FontWeight.w600)),
                        ElevatedButton.icon(
                          onPressed: _addBooth,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Booth'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade300)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                          // Exhibition selector
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                            child: DropdownButtonFormField<int>(
                              value: _selectedExhibitionId,
                              decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), filled: true, fillColor: Colors.grey.shade50),
                              hint: const Text('Select exhibition'),
                              items: _exhibitions.map((e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name))).toList(),
                              onChanged: (v) {
                                setState(() => _selectedExhibitionId = v);
                                _loadLayoutForSelectedExhibition();
                              },
                            ),
                          ),

                    // canvas area
                    SizedBox(
                      height: 360,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: Colors.grey.shade50,
                          child: Stack(
                            children: [
                              // Floor plan image background (if uploaded for this exhibition)
                              const Positioned.fill(child: ColoredBox(color: Color(0xFFFFFFFF))),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.85,
                                  child: _buildFloorPlanBackground(),
                                ),
                              ),

                              // grid background
                              const Positioned.fill(child: GridPaper(interval: 40.0, color: Colors.grey, subdivisions: 4)),

                              // booths
                              ..._booths.map((b) {
                                final id = b['id'] as int;
                                final left = b['left'] as double;
                                final top = b['top'] as double;
                                final isSelected = _selectedBoothId == id;
                                return Positioned(
                                  left: left,
                                  top: top,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedBoothId = id),
                                    onPanUpdate: (details) {
                                      setState(() {
                                        b['left'] = (b['left'] as double) + details.delta.dx;
                                        b['top'] = (b['top'] as double) + details.delta.dy;
                                      });
                                    },
                                    child: Container(
                                      width: b['width'] as double,
                                      height: b['height'] as double,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue.shade400 : Colors.white,
                                        border: Border.all(color: Colors.black87),
                                        boxShadow: isSelected
                                            ? [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))]
                                            : null,
                                      ),
                                      child: Text(b['number'], style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                );
                              }).toList(),

                              // entrance/exit labels (mock)
                              Positioned(top: 6, left: 40, right: 40, child: _labelBox('ENTRANCE')),
                              Positioned(bottom: 6, left: 40, right: 40, child: _labelBox('EXIT')),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text('${_booths.length} booths mapped', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Booth details
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Booth Details', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_selectedBoothId != null) Text('ID: $_selectedBoothId', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (selectedBooth != null) ...[
                      TextFormField(
                        key: ValueKey('boothNumber_${_selectedBoothId ?? 0}'),
                        initialValue: (selectedBooth['number'] as String?) ?? '',
                        decoration: const InputDecoration(labelText: 'Booth Number'),
                        onChanged: (v) => setState(() => selectedBooth['number'] = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('boothType_${_selectedBoothId ?? 0}'),
                        value: ((selectedBooth['type'] as String?) ?? 'Standard'),
                        items: boothTypeOptions.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => selectedBooth['type'] = (v ?? 'Standard')),
                        decoration: const InputDecoration(labelText: 'Booth Type'),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        ElevatedButton(onPressed: _saveLayout, child: const Text('Save')),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: _removeSelected, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                      ])
                    ] else
                      const Text('Select a booth on the canvas to view/edit details', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadExhibitions() async {
    try {
      final exs = await _db.getMyExhibitions();
      setState(() {
        _exhibitions = exs;
        if (_exhibitions.isNotEmpty && _selectedExhibitionId == null) {
          _selectedExhibitionId = _exhibitions.first.id;
        }
      });

      await _loadLayoutForSelectedExhibition();
    } catch (e) {
      // ignore errors for now
    }
  }

  Widget _labelBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), color: Colors.white),
      child: Center(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
    );
  }
}
