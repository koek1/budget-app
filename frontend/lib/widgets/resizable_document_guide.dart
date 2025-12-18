import 'package:flutter/material.dart';

class ResizableDocumentGuide extends StatefulWidget {
  const ResizableDocumentGuide({super.key});

  @override
  State<ResizableDocumentGuide> createState() => _ResizableDocumentGuideState();
}

class _ResizableDocumentGuideState extends State<ResizableDocumentGuide> {
  // More rectangular initial size (wider, less tall)
  double _left = 0.06;
  double _top = 0.20;
  double _right = 0.06;
  double _bottom = 0.30;
  
  Offset? _initialDragPosition;
  Rect? _initialGuideRect;
  String? _dragHandle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        final guideLeft = screenWidth * _left;
        final guideTop = screenHeight * _top;
        final guideRight = screenWidth * (1 - _right);
        final guideBottom = screenHeight * (1 - _bottom);
        
        final guideRect = Rect.fromLTRB(
          guideLeft,
          guideTop,
          guideRight,
          guideBottom,
        );

        return CustomPaint(
          painter: DocumentGuidePainter(guideRect: guideRect),
              child: GestureDetector(
                onPanStart: (details) {
                  final localPosition = details.localPosition;
                  _dragHandle = _getHandleAt(localPosition, guideRect);
                  if (_dragHandle != null) {
                    _initialDragPosition = localPosition;
                    _initialGuideRect = guideRect;
                  }
                },
                onPanUpdate: (details) {
                  if (_dragHandle == null || _initialDragPosition == null || _initialGuideRect == null) return;
                  
                  final currentPosition = details.localPosition;
                  final delta = currentPosition - _initialDragPosition!;
                  
                  setState(() {
                    if (_dragHandle == 'topLeft') {
                      _left = ((_initialGuideRect!.left + delta.dx) / screenWidth).clamp(0.05, 0.4);
                      _top = ((_initialGuideRect!.top + delta.dy) / screenHeight).clamp(0.05, 0.4);
                    } else if (_dragHandle == 'topRight') {
                      _right = ((screenWidth - _initialGuideRect!.right - delta.dx) / screenWidth).clamp(0.05, 0.4);
                      _top = ((_initialGuideRect!.top + delta.dy) / screenHeight).clamp(0.05, 0.4);
                    } else if (_dragHandle == 'bottomLeft') {
                      _left = ((_initialGuideRect!.left + delta.dx) / screenWidth).clamp(0.05, 0.4);
                      _bottom = ((screenHeight - _initialGuideRect!.bottom - delta.dy) / screenHeight).clamp(0.15, 0.5);
                    } else if (_dragHandle == 'bottomRight') {
                      _right = ((screenWidth - _initialGuideRect!.right - delta.dx) / screenWidth).clamp(0.05, 0.4);
                      _bottom = ((screenHeight - _initialGuideRect!.bottom - delta.dy) / screenHeight).clamp(0.15, 0.5);
                    } else if (_dragHandle == 'top') {
                      _top = ((_initialGuideRect!.top + delta.dy) / screenHeight).clamp(0.05, 0.4);
                    } else if (_dragHandle == 'bottom') {
                      _bottom = ((screenHeight - _initialGuideRect!.bottom - delta.dy) / screenHeight).clamp(0.15, 0.5);
                    } else if (_dragHandle == 'left') {
                      _left = ((_initialGuideRect!.left + delta.dx) / screenWidth).clamp(0.05, 0.4);
                    } else if (_dragHandle == 'right') {
                      _right = ((screenWidth - _initialGuideRect!.right - delta.dx) / screenWidth).clamp(0.05, 0.4);
                    }
                  });
                },
                onPanEnd: (_) {
                  _dragHandle = null;
                  _initialDragPosition = null;
                  _initialGuideRect = null;
                },
                child: Container(color: Colors.transparent),
              ),
        );
      },
    );
  }

  String? _getHandleAt(Offset position, Rect guideRect) {
    const handleSize = 30.0;
    const edgeTolerance = 20.0;

    // Check corners
    if ((position - Offset(guideRect.left, guideRect.top)).distance < handleSize) {
      return 'topLeft';
    }
    if ((position - Offset(guideRect.right, guideRect.top)).distance < handleSize) {
      return 'topRight';
    }
    if ((position - Offset(guideRect.left, guideRect.bottom)).distance < handleSize) {
      return 'bottomLeft';
    }
    if ((position - Offset(guideRect.right, guideRect.bottom)).distance < handleSize) {
      return 'bottomRight';
    }

    // Check edges
    if ((position.dy - guideRect.top).abs() < edgeTolerance &&
        position.dx >= guideRect.left && position.dx <= guideRect.right) {
      return 'top';
    }
    if ((position.dy - guideRect.bottom).abs() < edgeTolerance &&
        position.dx >= guideRect.left && position.dx <= guideRect.right) {
      return 'bottom';
    }
    if ((position.dx - guideRect.left).abs() < edgeTolerance &&
        position.dy >= guideRect.top && position.dy <= guideRect.bottom) {
      return 'left';
    }
    if ((position.dx - guideRect.right).abs() < edgeTolerance &&
        position.dy >= guideRect.top && position.dy <= guideRect.bottom) {
      return 'right';
    }

    return null;
  }
}

class DocumentGuidePainter extends CustomPainter {
  final Rect guideRect;

  DocumentGuidePainter({required this.guideRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkened overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Create cutout path for the guide area
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(guideRect, Radius.circular(12)));

    // Draw the cutout (clear area for document)
    final fullRect = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullRect,
      cutoutPath,
    );
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw guide frame border
    final borderPaint = Paint()
      ..color = Color(0xFF14B8A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, Radius.circular(12)),
      borderPaint,
    );

    // Draw corner indicators (L shapes) - fixed directions
    final cornerPaint = Paint()
      ..color = Color(0xFF14B8A6)
      ..style = PaintingStyle.fill;

    final cornerLength = 30.0;
    final cornerThickness = 4.0;

    // Top-left corner: L pointing to top-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.top, cornerLength, cornerThickness),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.top, cornerThickness, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Top-right corner: L pointing to top-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerLength, guideRect.top, cornerLength, cornerThickness),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerThickness, guideRect.top, cornerThickness, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Bottom-left corner: L pointing to bottom-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.bottom - cornerThickness, cornerLength, cornerThickness),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.bottom - cornerLength, cornerThickness, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Bottom-right corner: L pointing to bottom-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerLength, guideRect.bottom - cornerThickness, cornerLength, cornerThickness),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerThickness, guideRect.bottom - cornerLength, cornerThickness, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(DocumentGuidePainter oldDelegate) {
    return oldDelegate.guideRect != guideRect;
  }
}

