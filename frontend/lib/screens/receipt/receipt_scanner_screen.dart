import 'dart:io';
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
          SnackBar(content: Text('Failed to process receipt: $e')),
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
          'Scan Receipt',
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
                    'Processing receipt...',
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
        // Overlay with guide
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(),
                ),
                // Receipt guide frame
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFF14B8A6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Position receipt within frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(),
                ),
                // Capture button
                Padding(
                  padding: EdgeInsets.only(bottom: 40),
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
                  
                  // Action buttons
                  Row(
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
                    'Could not extract receipt data',
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

