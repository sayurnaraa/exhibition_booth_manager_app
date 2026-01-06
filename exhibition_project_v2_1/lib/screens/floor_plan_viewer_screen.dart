import 'dart:io';

import 'package:flutter/material.dart';

class FloorPlanViewerScreen extends StatefulWidget {
  final String exhibitionName;
  final Map<String, dynamic> floorPlan;

  const FloorPlanViewerScreen({
    super.key,
    required this.exhibitionName,
    required this.floorPlan,
  });

  @override
  State<FloorPlanViewerScreen> createState() => _FloorPlanViewerScreenState();
}

class _FloorPlanViewerScreenState extends State<FloorPlanViewerScreen> {
  final TransformationController _transformationController = TransformationController();

  static const double _minScale = 0.5;
  static const double _maxScale = 6.0;
  static const double _zoomStep = 1.25;

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp');
  }

  String _cleanExhibitionName(String name) {
    // Remove a trailing "- Test" suffix if present.
    return name.replaceFirst(RegExp(r'\s*-\s*test\s*\z', caseSensitive: false), '').trim();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetToCenter() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final appliedFactor = targetScale / currentScale;
    if (appliedFactor == 1.0) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      _transformationController.value = _transformationController.value *
          Matrix4.diagonal3Values(appliedFactor, appliedFactor, 1);
      return;
    }

    final focalPoint = renderObject.size.center(Offset.zero);
    final zoom = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(appliedFactor)
      ..translate(-focalPoint.dx, -focalPoint.dy);

    _transformationController.value = zoom * _transformationController.value;
  }

  @override
  Widget build(BuildContext context) {
    final displayExhibitionName = _cleanExhibitionName(widget.exhibitionName);
    final filePath = (widget.floorPlan['filePath'] as String?)?.trim() ?? '';
    final fileName = (widget.floorPlan['name'] as String?)?.trim().isNotEmpty == true
      ? widget.floorPlan['name'] as String
        : (filePath.isNotEmpty ? filePath.split(Platform.pathSeparator).last : 'Floor Plan');

    return Scaffold(
      appBar: AppBar(
        title: Text('Floor Plan - $displayExhibitionName'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: filePath.isEmpty
            ? const Center(child: Text('No floor plan file path found.'))
            : FutureBuilder<bool>(
                future: File(filePath).exists(),
                builder: (context, snapshot) {
                  final exists = snapshot.data == true;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!exists) {
                    return Center(
                      child: Text(
                        'Floor plan file not found on device.\n\n$fileName',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (!_isImageFile(filePath)) {
                    return Center(
                      child: Text(
                        'Preview not supported for this file type.\n\n$fileName',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black12,
                      child: Stack(
                        children: [
                          InteractiveViewer(
                            transformationController: _transformationController,
                            panEnabled: true,
                            scaleEnabled: true,
                            boundaryMargin: const EdgeInsets.all(48),
                            minScale: _minScale,
                            maxScale: _maxScale,
                            alignment: Alignment.center,
                            child: Center(
                              child: Image.file(
                                File(filePath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      'Failed to load image.\n\n$fileName',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (frame == null && !wasSynchronouslyLoaded) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  // Ensure the image starts centered.
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _resetToCenter();
                                  });
                                  return child;
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Material(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Zoom in',
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _zoomBy(_zoomStep),
                                  ),
                                  const Divider(height: 1),
                                  IconButton(
                                    tooltip: 'Zoom out',
                                    icon: const Icon(Icons.remove),
                                    onPressed: () => _zoomBy(1 / _zoomStep),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
