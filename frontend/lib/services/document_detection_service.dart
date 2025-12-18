import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Represents detected document corners
class DocumentCorners {
  final Offset? topLeft;
  final Offset? topRight;
  final Offset? bottomLeft;
  final Offset? bottomRight;
  final double confidence;

  DocumentCorners({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.confidence = 0.0,
  });

  bool get isValid => topLeft != null && topRight != null && 
                      bottomLeft != null && bottomRight != null;

  List<Offset> get corners => [
    if (topLeft != null) topLeft!,
    if (topRight != null) topRight!,
    if (bottomRight != null) bottomRight!,
    if (bottomLeft != null) bottomLeft!,
  ];
}

class DocumentDetectionService {
  /// Detect document edges from camera image using edge detection
  /// This works for ANY document type, not just text-based documents
  static Future<DocumentCorners?> detectDocument(
    CameraImage cameraImage,
    Size previewSize,
  ) async {
    try {
      // Convert camera image to processable format
      final image = _cameraImageToImage(cameraImage);
      if (image == null) return null;

      // Resize for faster processing (maintain aspect ratio)
      final scaleFactor = math.min(400.0 / image.width, 400.0 / image.height);
      final processedWidth = (image.width * scaleFactor).round();
      final processedHeight = (image.height * scaleFactor).round();
      final resizedImage = img.copyResize(
        image,
        width: processedWidth,
        height: processedHeight,
      );

      // Convert to grayscale for edge detection
      final grayImage = img.grayscale(resizedImage);

      // Apply Gaussian blur to reduce noise
      final blurredImage = img.gaussianBlur(grayImage, radius: 2);

      // Apply Canny edge detection
      final edgeImage = _cannyEdgeDetection(blurredImage);

      // Find contours (connected edge regions)
      final contours = _findContours(edgeImage);

      // Find the best rectangular contour (likely document)
      final documentRect = _findBestDocumentRect(contours, processedWidth, processedHeight);

      if (documentRect == null) {
        return DocumentCorners(confidence: 0.0);
      }

      // Scale corners back to original preview size
      final scaleX = previewSize.width / processedWidth;
      final scaleY = previewSize.height / processedHeight;

      final topLeft = Offset(
        documentRect.left * scaleX,
        documentRect.top * scaleY,
      );
      final topRight = Offset(
        documentRect.right * scaleX,
        documentRect.top * scaleY,
      );
      final bottomRight = Offset(
        documentRect.right * scaleX,
        documentRect.bottom * scaleY,
      );
      final bottomLeft = Offset(
        documentRect.left * scaleX,
        documentRect.bottom * scaleY,
      );

      // Calculate confidence based on rectangle quality
      final rectArea = documentRect.width * documentRect.height;
      final imageArea = previewSize.width * previewSize.height;
      final coverage = rectArea / imageArea;
      
      double confidence = (coverage * 3.0).clamp(0.0, 1.0);
      
      // Boost confidence for reasonable document sizes
      if (coverage > 0.1 && coverage < 0.9) {
        confidence = (confidence * 1.2).clamp(0.0, 1.0);
      }

      // Validate aspect ratio
      final aspectRatio = documentRect.width / documentRect.height;
      if (aspectRatio >= 0.3 && aspectRatio <= 3.0) {
        confidence = (confidence * 1.1).clamp(0.0, 1.0);
      }

      return DocumentCorners(
        topLeft: topLeft,
        topRight: topRight,
        bottomRight: bottomRight,
        bottomLeft: bottomLeft,
        confidence: confidence,
      );
    } catch (e) {
      print('Error detecting document: $e');
      return null;
    }
  }

  /// Convert CameraImage to img.Image for processing
  static img.Image? _cameraImageToImage(CameraImage cameraImage) {
    try {
      // CameraImage is in YUV420 format (NV21 on Android)
      // Extract Y plane (luminance) for grayscale processing
      final yPlane = cameraImage.planes[0];
      final yBytes = yPlane.bytes;
      
      // Create image from Y plane
      final image = img.Image(
        width: cameraImage.width,
        height: cameraImage.height,
      );

      // Convert Y bytes to grayscale image
      for (int y = 0; y < cameraImage.height; y++) {
        for (int x = 0; x < cameraImage.width; x++) {
          final index = y * yPlane.bytesPerRow + x;
          if (index < yBytes.length) {
            final luminance = yBytes[index];
            image.setPixel(x, y, img.ColorRgb8(luminance, luminance, luminance));
          }
        }
      }

      return image;
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Canny edge detection algorithm
  static img.Image _cannyEdgeDetection(img.Image image) {
    // Apply Sobel operator for gradient detection
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    final width = image.width;
    final height = image.height;
    final gradient = List.generate(height, (_) => List<double>.filled(width, 0.0));
    final direction = List.generate(height, (_) => List<double>.filled(width, 0.0));

    // Calculate gradients
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0, gy = 0;
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            final pixel = image.getPixel(x + j, y + i);
            final gray = img.getLuminance(pixel);
            gx += gray * sobelX[i + 1][j + 1];
            gy += gray * sobelY[i + 1][j + 1];
          }
        }
        gradient[y][x] = math.sqrt(gx * gx + gy * gy);
        direction[y][x] = math.atan2(gy, gx);
      }
    }

    // Non-maximum suppression and thresholding
    final edgeImage = img.Image(width: width, height: height);
    final lowThreshold = 30.0;
    final highThreshold = 100.0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final mag = gradient[y][x];
        if (mag > highThreshold) {
          edgeImage.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else if (mag > lowThreshold) {
          // Check neighbors for edge continuation
          bool isEdge = false;
          final angle = direction[y][x];
          if ((angle >= -math.pi / 8 && angle < math.pi / 8) ||
              angle >= 7 * math.pi / 8 || angle < -7 * math.pi / 8) {
            // Horizontal edge
            isEdge = mag >= gradient[y][x - 1] && mag >= gradient[y][x + 1];
          } else if ((angle >= math.pi / 8 && angle < 3 * math.pi / 8) ||
                     (angle >= -7 * math.pi / 8 && angle < -5 * math.pi / 8)) {
            // Diagonal edge (top-right to bottom-left)
            isEdge = mag >= gradient[y - 1][x + 1] && mag >= gradient[y + 1][x - 1];
          } else if ((angle >= 3 * math.pi / 8 && angle < 5 * math.pi / 8) ||
                     (angle >= -5 * math.pi / 8 && angle < -3 * math.pi / 8)) {
            // Vertical edge
            isEdge = mag >= gradient[y - 1][x] && mag >= gradient[y + 1][x];
          } else {
            // Diagonal edge (top-left to bottom-right)
            isEdge = mag >= gradient[y - 1][x - 1] && mag >= gradient[y + 1][x + 1];
          }
          if (isEdge) {
            edgeImage.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }
      }
    }

    return edgeImage;
  }

  /// Find contours (connected edge regions)
  static List<List<Offset>> _findContours(img.Image edgeImage) {
    final contours = <List<Offset>>[];
    final visited = List.generate(
      edgeImage.height,
      (_) => List<bool>.filled(edgeImage.width, false),
    );

    for (int y = 0; y < edgeImage.height; y++) {
      for (int x = 0; x < edgeImage.width; x++) {
        final pixel = edgeImage.getPixel(x, y);
        if (img.getLuminance(pixel) > 128 && !visited[y][x]) {
          final contour = _traceContour(edgeImage, visited, x, y);
          if (contour.length > 20) { // Filter small noise
            contours.add(contour);
          }
        }
      }
    }

    return contours;
  }

  /// Trace a single contour using 8-connected neighbors
  static List<Offset> _traceContour(
    img.Image edgeImage,
    List<List<bool>> visited,
    int startX,
    int startY,
  ) {
    final contour = <Offset>[];
    final stack = <Point>[];
    stack.add(Point(startX, startY));

    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;

      if (x < 0 || x >= edgeImage.width || y < 0 || y >= edgeImage.height) {
        continue;
      }
      if (visited[y][x]) {
        continue;
      }

      final pixel = edgeImage.getPixel(x, y);
      if (img.getLuminance(pixel) <= 128) {
        continue;
      }

      visited[y][x] = true;
      contour.add(Offset(x.toDouble(), y.toDouble()));

      // Add 8-connected neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          stack.add(Point(x + dx, y + dy));
        }
      }
    }

    return contour;
  }

  /// Find the best rectangular contour that likely represents a document
  static Rect? _findBestDocumentRect(
    List<List<Offset>> contours,
    int imageWidth,
    int imageHeight,
  ) {
    Rect? bestRect;
    double bestScore = 0.0;

    for (final contour in contours) {
      if (contour.length < 4) continue;

      // Approximate contour with polygon
      final approxRect = _approximateRect(contour);
      if (approxRect == null) continue;

      // Calculate score based on:
      // 1. Size (should be reasonable portion of image)
      // 2. Aspect ratio (should be document-like)
      // 3. Rectangularity (how close to a rectangle)
      final area = approxRect.width * approxRect.height;
      final imageArea = imageWidth * imageHeight;
      final coverage = area / imageArea;

      if (coverage < 0.05 || coverage > 0.95) continue; // Too small or too large

      final aspectRatio = approxRect.width / approxRect.height;
      if (aspectRatio < 0.2 || aspectRatio > 5.0) continue; // Unreasonable aspect ratio

      // Calculate rectangularity (how well the contour fits the bounding rect)
      final boundingArea = area;
      final contourArea = _calculateContourArea(contour);
      final rectangularity = contourArea > 0 ? boundingArea / contourArea : 0.0;
      if (rectangularity > 1.5) continue; // Not rectangular enough

      // Score combines coverage, aspect ratio, and rectangularity
      double score = coverage * 0.4 +
                     (1.0 - (aspectRatio - 1.0).abs() / 4.0) * 0.3 +
                     (1.0 / rectangularity) * 0.3;

      if (score > bestScore) {
        bestScore = score;
        bestRect = approxRect;
      }
    }

    return bestRect;
  }

  /// Approximate contour as a rectangle
  static Rect? _approximateRect(List<Offset> contour) {
    if (contour.isEmpty) return null;

    // Find bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final point in contour) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }

    if (minX >= maxX || minY >= maxY) return null;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculate area of contour using shoelace formula
  static double _calculateContourArea(List<Offset> contour) {
    if (contour.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < contour.length; i++) {
      final j = (i + 1) % contour.length;
      area += contour[i].dx * contour[j].dy;
      area -= contour[j].dx * contour[i].dy;
    }
    return area.abs() / 2.0;
  }
}

/// Simple point class for contour tracing
class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}
