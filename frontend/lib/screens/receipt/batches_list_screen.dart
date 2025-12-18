import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budget_app/models/receipt_batch.dart';
import 'package:budget_app/services/receipt_batch_service.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/screens/receipt/batch_view_screen.dart';
import 'package:budget_app/screens/receipt/batch_receipt_scanner_screen.dart';
import 'package:intl/intl.dart';

class BatchesListScreen extends StatefulWidget {
  const BatchesListScreen({super.key});

  @override
  State<BatchesListScreen> createState() => _BatchesListScreenState();
}

class _BatchesListScreenState extends State<BatchesListScreen> {
  List<ReceiptBatch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final batches = await ReceiptBatchService.getBatches();
      if (mounted) {
        setState(() {
          _batches = batches;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading batches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startBatchScan() async {
    final result = await Navigator.push<ReceiptBatch?>(
      context,
      MaterialPageRoute(
        builder: (context) => BatchReceiptScannerScreen(),
      ),
    );

    if (result != null) {
      // Refresh batches list
      _loadBatches();
      // Optionally navigate to the new batch
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BatchViewScreen(batchId: result.id),
        ),
      ).then((_) => _loadBatches());
    } else {
      // Refresh anyway in case batch was created
      _loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt Batches'),
            Text(
              'Organize multiple receipts together',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
            )
          : _batches.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Color(0xFF14B8A6).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.folder,
                            size: 64,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No Receipt Batches Yet',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Batch scanning lets you scan multiple receipts at once and organize them together. Perfect for shopping trips or expense reports!',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Color(0xFF14B8A6), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'How it works:',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              _buildFeatureItem(
                                Icons.camera_alt,
                                'Scan multiple receipts',
                                'Capture receipts one by one',
                              ),
                              SizedBox(height: 12),
                              _buildFeatureItem(
                                Icons.edit,
                                'Edit each transaction',
                                'Review and adjust details before saving',
                              ),
                              SizedBox(height: 12),
                              _buildFeatureItem(
                                Icons.folder,
                                'Organized in batches',
                                'All receipts saved together with totals',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _startBatchScan,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Start Your First Batch Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBatches,
                  color: Color(0xFF14B8A6),
                  child: Column(
                    children: [
                      // Start new batch button
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: _startBatchScan,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Start New Batch Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      // Batches list
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _batches.length,
                          itemBuilder: (context, index) {
                            final batch = _batches[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF14B8A6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.folder,
                                    color: Color(0xFF14B8A6),
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  batch.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text(
                                      '${batch.transactionIds.length} transaction(s)',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      DateFormat('MMM dd, yyyy HH:mm')
                                          .format(batch.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Helpers.formatCurrency(batch.totalAmount),
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BatchViewScreen(batchId: batch.id),
                                    ),
                                  ).then((_) => _loadBatches());
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _batches.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startBatchScan,
              backgroundColor: Color(0xFF14B8A6),
              icon: Icon(Icons.camera_alt),
              label: Text('New Batch'),
            )
          : null,
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Color(0xFF14B8A6), size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

