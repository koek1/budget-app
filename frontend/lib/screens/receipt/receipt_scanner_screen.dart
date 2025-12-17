import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:budget_app/services/receipt_scanner_service.dart';
import 'package:budget_app/utils/helpers.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _showPreview = false;
  String? _capturedImagePath;
  ReceiptData? _scannedData;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImagePath = image.path;
        _showPreview = true;
      });

      // Process the image
      await _processImage(image.path);
    } catch (e) {
      print('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final receiptData = await ReceiptScannerService.processReceiptImage(imagePath);
      setState(() {
        _scannedData = receiptData;
        _isProcessing = false;
      });
    } catch (e) {
      print('Error processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process document: $e')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      final image = await ReceiptScannerService.pickReceiptFromGallery();
      if (image != null) {
        setState(() {
          _capturedImagePath = image.path;
          _showPreview = true;
        });
        await _processImage(image.path);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _showPreview = false;
      _capturedImagePath = null;
      _scannedData = null;
    });
  }

  void _useScannedData() {
    if (_scannedData != null) {
      Navigator.pop(context, _scannedData);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan Document',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library, color: Colors.white),
            onPressed: _isProcessing ? null : _pickFromGallery,
            tooltip: 'Pick from Gallery',
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF14B8A6)),
                  SizedBox(height: 16),
                  Text(
                    'Processing document...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : _showPreview && _capturedImagePath != null
              ? _buildPreviewScreen(theme)
              : _buildCameraScreen(theme),
    );
  }

  Widget _buildCameraScreen(ThemeData theme) {
    if (!_isInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF14B8A6)),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        // Fixed overlay with guide frame
        Positioned.fill(
          child: CustomPaint(
            painter: DocumentGuidePainter(),
            child: Column(
              children: [
                // Top guidance text
                SafeArea(
                  child: Container(
                    margin: EdgeInsets.only(top: 20),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Position document within the frame for a clearer picture',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Spacer(),
                // Capture button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 120,
                  ),
                  child: GestureDetector(
                    onTap: _captureImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Color(0xFF14B8A6),
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewScreen(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Image preview
          Container(
            width: double.infinity,
            height: 400,
            color: Colors.black,
            child: _capturedImagePath != null
                ? Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.contain,
                  )
                : SizedBox(),
          ),
          
          // Scanned data
          if (_scannedData != null) ...[
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Confidence indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _scannedData!.confidence > 0.7
                          ? Colors.green.withOpacity(0.1)
                          : _scannedData!.confidence > 0.4
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _scannedData!.confidence > 0.7
                              ? Icons.check_circle
                              : _scannedData!.confidence > 0.4
                                  ? Icons.warning
                                  : Icons.error,
                          size: 16,
                          color: _scannedData!.confidence > 0.7
                              ? Colors.green
                              : _scannedData!.confidence > 0.4
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Confidence: ${(_scannedData!.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _scannedData!.confidence > 0.7
                                ? Colors.green
                                : _scannedData!.confidence > 0.4
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Amount
                  if (_scannedData!.amount != null)
                    _buildDataRow(
                      theme,
                      'Amount',
                      Helpers.formatCurrency(_scannedData!.amount!),
                      Icons.attach_money,
                      Colors.green,
                    ),
                  
                  // Date
                  if (_scannedData!.date != null)
                    _buildDataRow(
                      theme,
                      'Date',
                      '${_scannedData!.date!.day}/${_scannedData!.date!.month}/${_scannedData!.date!.year}',
                      Icons.calendar_today,
                      Colors.blue,
                    ),
                  
                  // Merchant
                  if (_scannedData!.merchantName != null)
                    _buildDataRow(
                      theme,
                      'Merchant',
                      _scannedData!.merchantName!,
                      Icons.store,
                      Colors.purple,
                    ),
                  
                  // Category suggestion
                  if (_scannedData!.suggestedCategory != null)
                    _buildDataRow(
                      theme,
                      'Suggested Category',
                      _scannedData!.suggestedCategory!,
                      Icons.category,
                      Color(0xFF14B8A6),
                    ),
                  
                  // Description
                  if (_scannedData!.description != null)
                    _buildDataRow(
                      theme,
                      'Description',
                      _scannedData!.description!,
                      Icons.description,
                      Colors.orange,
                    ),
                  
                  SizedBox(height: 30),
                  
                  // Action buttons - account for bottom navigation
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _retakePhoto,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Color(0xFF14B8A6)),
                            ),
                            child: Text(
                              'Retake',
                              style: TextStyle(color: Color(0xFF14B8A6)),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _scannedData!.confidence > 0.3 ? _useScannedData : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF14B8A6),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Use This Data',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Could not extract document data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please try again with a clearer image',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retakePhoto,
                    child: Text('Retake Photo'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing fixed document guide frame
class DocumentGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkened overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Draw larger rectangular guide frame (more rectangular, not square)
    final horizontalMargin = size.width * 0.08; // 8% margin on sides
    final verticalMargin = size.height * 0.15; // 15% margin on top/bottom
    final guideRect = Rect.fromLTWH(
      horizontalMargin,
      verticalMargin,
      size.width - 2 * horizontalMargin,
      size.height - 2 * verticalMargin - 200, // Account for capture button area
    );

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

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Color(0xFF14B8A6)
      ..style = PaintingStyle.fill;

    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.top, cornerLength, 4),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.top, 4, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerLength, guideRect.top, cornerLength, 4),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - 4, guideRect.top, 4, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.bottom - 4, cornerLength, 4),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.left, guideRect.bottom - cornerLength, 4, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - cornerLength, guideRect.bottom - 4, cornerLength, 4),
        Radius.circular(2),
      ),
      cornerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(guideRect.right - 4, guideRect.bottom - cornerLength, 4, cornerLength),
        Radius.circular(2),
      ),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(DocumentGuidePainter oldDelegate) => false;
}

