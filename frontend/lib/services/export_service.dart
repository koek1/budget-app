import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'api_service.dart';

class ExportService {
  static Future<void> exportToExcel({
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final headers = await ApiService.getHeaders();
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/export/excel'),
        headers: headers,
        body: _buildRequestBody(startDate, endDate, reportType),
      );

      if (response.statusCode == 200) {
        // Get downloads directory
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          onError('Could not access downloads directory');
          return;
        }

        // Create file
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/budget-report-$timestamp.xlsx');
        
        // Write Excel data to file
        await file.writeAsBytes(response.bodyBytes);
        
        // Open the file
        await OpenFile.open(file.path);
        
        onSuccess('Report exported successfully!');
      } else {
        onError('Failed to export: ${response.statusCode}');
      }
    } catch (e) {
      onError('Export failed: $e');
    }
  }

  static String _buildRequestBody(DateTime startDate, DateTime endDate, String reportType) {
    return json.encode({
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reportType': reportType,
    });
  }

  static Future<Map<String, dynamic>> getReportSummary({
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      final headers = await ApiService.getHeaders();
      
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/export/summary?'
          'startDate=${startDate.toIso8601String().split('T')[0]}'
          '&endDate=${endDate.toIso8601String().split('T')[0]}'
          '&reportType=$reportType'
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Summary failed: $e');
    }
  }
}