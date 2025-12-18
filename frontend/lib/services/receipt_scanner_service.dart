import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/services/permission_service.dart';

class ReceiptData {
  final double? amount;
  final DateTime? date;
  final String? merchantName;
  final String? description;
  final String? suggestedCategory;
  final double confidence;

  ReceiptData({
    this.amount,
    this.date,
    this.merchantName,
    this.description,
    this.suggestedCategory,
    this.confidence = 0.0,
  });
}

class ReceiptScannerService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static final ImagePicker _imagePicker = ImagePicker();

  /// Scan receipt from camera
  static Future<XFile?> captureReceipt() async {
    try {
      // Mark that we're requesting camera permission
      // This prevents the app from logging out when the permission dialog appears
      PermissionService.startPermissionRequest();
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      // Permission request completed (either granted or denied)
      PermissionService.endPermissionRequest();
      
      return image;
    } catch (e) {
      // Make sure to end permission request even if there's an error
      PermissionService.endPermissionRequest();
      print('Error capturing image: $e');
      return null;
    }
  }

  /// Scan receipt from gallery
  static Future<XFile?> pickReceiptFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Process image and extract receipt data
  static Future<ReceiptData> processReceiptImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      return _parseReceiptText(recognizedText.text);
    } catch (e) {
      print('Error processing receipt: $e');
      return ReceiptData(confidence: 0.0);
    }
  }

  /// Parse OCR text to extract receipt information
  static ReceiptData _parseReceiptText(String text) {
    if (text.isEmpty) {
      return ReceiptData(confidence: 0.0);
    }

    final lines =
        text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    double confidence = 0.0;
    double? amount;
    DateTime? date;
    String? merchantName;
    String? description;

    // Extract amount (look for currency patterns)
    amount = _extractAmount(text, lines);
    if (amount != null) confidence += 0.4;

    // Extract date
    date = _extractDate(text, lines);
    if (date != null) confidence += 0.3;

    // Extract merchant name (usually first few lines)
    merchantName = _extractMerchantName(lines);
    if (merchantName != null) confidence += 0.2;

    // Extract description (items purchased)
    description = _extractDescription(lines);

    // Suggest category based on merchant name
    final suggestedCategory = _suggestCategory(merchantName, description);

    return ReceiptData(
      amount: amount,
      date: date ?? DateTime.now(), // Default to today if not found
      merchantName: merchantName,
      description: description,
      suggestedCategory: suggestedCategory,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  /// Extract amount from text
  static double? _extractAmount(String text, List<String> lines) {
    // Get user's preferred currency symbol from settings
    final userCurrency = SettingsService.getCurrencySymbol();
    // Escape special regex characters (especially $)
    final escapedCurrency = RegExp.escape(userCurrency);
    
    // All available currency symbols for fallback patterns
    final allCurrencies = ['\$', 'R', '£', '€'];
    final allCurrenciesEscaped = allCurrencies.map((c) => RegExp.escape(c)).join('');
    
    // Build patterns prioritizing user's currency
    final currencyPatterns = [
      // Priority 1: User's currency symbol before amount
      RegExp('$escapedCurrency\\s*(\\d+[.,]\\d{2})'),
      // Priority 2: Amount followed by user's currency symbol
      RegExp('(\\d+[.,]\\d{2})\\s*$escapedCurrency'),
      // Priority 3: TOTAL/AMOUNT/DUE/PAID with user's currency
      RegExp('TOTAL[:\\s]*$escapedCurrency?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('AMOUNT[:\\s]*$escapedCurrency?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('DUE[:\\s]*$escapedCurrency?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('PAID[:\\s]*$escapedCurrency?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      // Fallback: Any currency symbol (in case OCR misreads)
      RegExp('[$allCurrenciesEscaped]\\s*(\\d+[.,]\\d{2})'),
      RegExp('(\\d+[.,]\\d{2})\\s*[$allCurrenciesEscaped]'),
      RegExp('TOTAL[:\\s]*[$allCurrenciesEscaped]?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('AMOUNT[:\\s]*[$allCurrenciesEscaped]?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('DUE[:\\s]*[$allCurrenciesEscaped]?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      RegExp('PAID[:\\s]*[$allCurrenciesEscaped]?\\s*(\\d+[.,]\\d{2})', caseSensitive: false),
      // Final fallback: Large numbers with thousands separator (no currency symbol)
      RegExp(
          r'(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})'),
    ];

    // Try patterns in order (user's currency patterns first)
    for (final pattern in currencyPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ??
            match.group(0)?.replaceAll(RegExp(r'[^\d.]'), '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 1000000) {
            return amount;
          }
        }
      }
    }

    // Fallback: look for largest number that looks like an amount
    final numberPattern = RegExp(r'\d+[.,]\d{2}');
    final matches = numberPattern.allMatches(text);
    double? maxAmount;

    for (final match in matches) {
      final amountStr = match.group(0)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 1000000) {
          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;
          }
        }
      }
    }

    return maxAmount;
  }

  /// Extract date from text
  static DateTime? _extractDate(String text, List<String> lines) {
    // Common date patterns
    final datePatterns = [
      // DD/MM/YYYY or MM/DD/YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})'),
      // YYYY-MM-DD
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      // DD MMM YYYY or MMM DD, YYYY
      RegExp(r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})', caseSensitive: false),
      // Date keywords
      RegExp(r'(?:DATE|DATE:|DATED?)[:\s]*(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
          caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        try {
          DateTime? date;

          if (match.groupCount == 3) {
            final part1 = match.group(1)!;
            final part2 = match.group(2)!;
            final part3 = match.group(3)!;

            // Try different formats
            final formats = [
              'dd/MM/yyyy',
              'MM/dd/yyyy',
              'yyyy-MM-dd',
              'dd-MM-yyyy',
              'MM-dd-yyyy',
            ];

            for (final format in formats) {
              try {
                final dateStr = '$part1/$part2/$part3';
                date = DateFormat(format).parse(dateStr);
                // Validate date is reasonable (not too far in future/past)
                final now = DateTime.now();
                if (date.isAfter(now.subtract(Duration(days: 365))) &&
                    date.isBefore(now.add(Duration(days: 1)))) {
                  return date;
                }
              } catch (_) {
                // Try next format
              }
            }
          }
        } catch (e) {
          // Continue to next match
        }
      }
    }

    // Fallback: look for month names
    final monthNames = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];

    for (final line in lines.take(10)) {
      final lowerLine = line.toLowerCase();
      for (int i = 0; i < monthNames.length; i++) {
        if (lowerLine.contains(monthNames[i])) {
          final monthPattern = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
          final dateMatch = monthPattern.firstMatch(line);
          if (dateMatch != null) {
            try {
              final dateStr =
                  '${dateMatch.group(1)}/${dateMatch.group(2)}/${dateMatch.group(3)}';
              final date = DateFormat('dd/MM/yyyy').parse(dateStr);
              final now = DateTime.now();
              if (date.isAfter(now.subtract(Duration(days: 365))) &&
                  date.isBefore(now.add(Duration(days: 1)))) {
                return date;
              }
            } catch (_) {
              // Continue
            }
          }
        }
      }
    }

    return null;
  }

  /// Extract merchant name (usually in first few lines)
  static String? _extractMerchantName(List<String> lines) {
    if (lines.isEmpty) return null;

    // Skip common receipt header words
    final skipWords = [
      'receipt',
      'invoice',
      'bill',
      'thank',
      'you',
      'for',
      'your',
      'purchase',
      'date',
      'time',
      'transaction',
      'card',
      'cash',
      'change',
      'total',
      'subtotal',
      'tax',
      'discount',
      'amount',
      'paid',
      'balance'
    ];

    // Look at first 5 lines for merchant name
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip lines that are clearly not merchant names
      final lowerLine = line.toLowerCase();
      bool isSkipLine = false;
      for (final word in skipWords) {
        if (lowerLine.contains(word)) {
          isSkipLine = true;
          break;
        }
      }

      if (!isSkipLine && line.length > 2 && line.length < 50) {
        // Check if line looks like a merchant name (not all numbers, not a date)
        if (!RegExp(r'^\d+[.,]?\d*$').hasMatch(line) &&
            !RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line)) {
          return line;
        }
      }
    }

    return null;
  }

  /// Extract description/items from receipt
  static String? _extractDescription(List<String> lines) {
    final items = <String>[];

    // Look for item lines (usually have quantity, name, price)
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip header/footer lines
      if (RegExp(
              r'^(TOTAL|SUBTOTAL|TAX|DISCOUNT|AMOUNT|PAID|CHANGE|RECEIPT|INVOICE)',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }

      // Skip lines that are just numbers or dates
      if (RegExp(r'^[\d\s.,$R/-]+$').hasMatch(trimmed)) {
        continue;
      }

      // If line looks like an item (has text and possibly numbers)
      if (trimmed.length > 3 && trimmed.length < 100) {
        items.add(trimmed);
        if (items.length >= 5) break; // Limit to 5 items
      }
    }

    return items.isNotEmpty ? items.join(', ') : null;
  }

  /// Suggest category based on merchant name and description
  static String? _suggestCategory(String? merchantName, String? description) {
    final text = '${merchantName ?? ''} ${description ?? ''}'.toLowerCase();

    // Category keyword mappings
    final categoryKeywords = {
      'Food & Dining': [
        'restaurant',
        'cafe',
        'coffee',
        'food',
        'dining',
        'pizza',
        'burger',
        'mcdonald',
        'kfc',
        'starbucks',
        'subway',
        'domino',
        'pizza hut',
        'bakery',
        'baker',
        'deli',
        'fast food',
        'takeaway',
        'take away',
        'grill',
        'steak',
        'sushi',
        'chinese',
        'italian',
        'mexican',
        'indian',
        'grocery',
        'supermarket',
        'walmart',
        'target',
        'pick n pay',
        'checkers',
        'woolworths',
        'spar',
        'shoprite',
        'food',
        'meal',
        'lunch',
        'dinner',
        'breakfast',
        'snack',
        'drink',
        'beverage'
      ],
      'Shopping': [
        'shop',
        'store',
        'retail',
        'mall',
        'clothing',
        'fashion',
        'apparel',
        'shoes',
        'jewelry',
        'jewellery',
        'accessories',
        'department',
        'outlet',
        'boutique',
        'market',
        'vendor',
        'merchant',
        'seller',
        'buy',
        'purchase',
        'zara',
        'h&m',
        'nike',
        'adidas',
        'amazon',
        'ebay',
        'online'
      ],
      'Entertainment': [
        'cinema',
        'movie',
        'theater',
        'theatre',
        'concert',
        'show',
        'ticket',
        'entertainment',
        'game',
        'arcade',
        'bowling',
        'karaoke',
        'club',
        'bar',
        'pub',
        'nightclub',
        'casino',
        'gambling',
        'netflix',
        'spotify',
        'streaming',
        'music',
        'video',
        'dvd',
        'cd'
      ],
      'Bills & Utilities': [
        'electric',
        'electricity',
        'water',
        'gas',
        'utility',
        'bill',
        'invoice',
        'phone',
        'mobile',
        'internet',
        'wifi',
        'broadband',
        'cable',
        'tv',
        'subscription',
        'service',
        'payment',
        'due',
        'account',
        'statement',
        'vodacom',
        'mtn',
        'cell c',
        'telkom',
        'eskom',
        'municipality'
      ],
      'Healthcare': [
        'pharmacy',
        'pharmaceutical',
        'medicine',
        'drug',
        'prescription',
        'doctor',
        'clinic',
        'hospital',
        'medical',
        'health',
        'dental',
        'dentist',
        'optometrist',
        'glasses',
        'contact',
        'lens',
        'dischem',
        'clicks',
        'mediclinic',
        'netcare',
        'life healthcare'
      ],
      'Education': [
        'school',
        'university',
        'college',
        'tuition',
        'course',
        'training',
        'education',
        'book',
        'textbook',
        'stationery',
        'stationary',
        'supplies',
        'library',
        'student',
        'exam',
        'test'
      ],
      'Travel': [
        'airline',
        'flight',
        'hotel',
        'motel',
        'lodging',
        'accommodation',
        'travel',
        'trip',
        'vacation',
        'holiday',
        'tour',
        'taxi',
        'uber',
        'bolt',
        'lyft',
        'transport',
        'bus',
        'train',
        'metro',
        'subway',
        'rental',
        'car',
        'parking',
        'fuel',
        'petrol',
        'gas station',
        'garage',
        'coffee',
        'cafe',
        'espresso',
        'latte',
        'cappuccino',
        'starbucks',
        'seattle',
        'coffee shop',
        'barista',
        'ride',
        'cab',
        'driver'
      ],
    };

    // Score each category
    final categoryScores = <String, int>{};

    for (final entry in categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          score += keyword.length; // Longer keywords get more weight
        }
      }
      if (score > 0) {
        categoryScores[entry.key] = score;
      }
    }

    // Return category with highest score
    if (categoryScores.isEmpty) return null;

    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.first.key;
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
