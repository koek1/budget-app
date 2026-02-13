import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:budget_app/models/weekly_reflection.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/utils/helpers.dart';

class WeeklyReflectionScreen extends StatefulWidget {
  const WeeklyReflectionScreen({super.key});

  @override
  State<WeeklyReflectionScreen> createState() => _WeeklyReflectionScreenState();
}

class _WeeklyReflectionScreenState extends State<WeeklyReflectionScreen> {
  final _wentWellController = TextEditingController();
  final _regretController = TextEditingController();
  final _goalController = TextEditingController();
  bool _isSaving = false;
  bool _isEditing = false;
  WeeklyReflection? _existingReflection;

  @override
  void initState() {
    super.initState();
    _loadExistingReflection();
  }

  @override
  void dispose() {
    _wentWellController.dispose();
    _regretController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  DateTime get _currentWeekStart {
    final now = DateTime.now();
    final weekday = now.weekday; // Monday = 1
    return DateTime(now.year, now.month, now.day - (weekday - 1));
  }

  Future<void> _loadExistingReflection() async {
    try {
      final currentUser = await LocalStorageService.getCurrentUser();
      if (currentUser == null) return;

      if (!Hive.isBoxOpen('weeklyReflectionsBox')) return;
      final box = Hive.box<WeeklyReflection>('weeklyReflectionsBox');
      final weekStart = _currentWeekStart;

      for (var reflection in box.values) {
        if (reflection.userId == currentUser.id &&
            reflection.weekStarting.year == weekStart.year &&
            reflection.weekStarting.month == weekStart.month &&
            reflection.weekStarting.day == weekStart.day) {
          setState(() {
            _existingReflection = reflection;
            _wentWellController.text = reflection.wentWell;
            _regretController.text = reflection.regret;
            _goalController.text = reflection.nextWeekGoal;
            _isEditing = true;
          });
          return;
        }
      }
    } catch (e) {
      print('Error loading reflection: $e');
    }
  }

  Future<void> _saveReflection() async {
    if (_wentWellController.text.trim().isEmpty &&
        _regretController.text.trim().isEmpty &&
        _goalController.text.trim().isEmpty) {
      Helpers.showErrorSnackBar(context, 'Please fill in at least one field');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = await LocalStorageService.getCurrentUser();
      if (currentUser == null) throw Exception('Not logged in');

      if (!Hive.isBoxOpen('weeklyReflectionsBox')) {
        throw Exception('Reflections database not available');
      }
      final box = Hive.box<WeeklyReflection>('weeklyReflectionsBox');

      final reflection = WeeklyReflection(
        id: _existingReflection?.id ?? const Uuid().v4(),
        userId: currentUser.id,
        weekStarting: _currentWeekStart,
        wentWell: _wentWellController.text.trim(),
        regret: _regretController.text.trim(),
        nextWeekGoal: _goalController.text.trim(),
        createdAt: _existingReflection?.createdAt ?? DateTime.now(),
      );

      if (_isEditing && _existingReflection != null) {
        // Find and update existing
        for (var i = 0; i < box.length; i++) {
          final existing = box.getAt(i);
          if (existing?.id == _existingReflection!.id) {
            await box.putAt(i, reflection);
            break;
          }
        }
      } else {
        await box.add(reflection);
      }

      if (mounted) {
        Helpers.showSuccessSnackBar(
          context,
          _isEditing ? 'Reflection updated' : 'Reflection saved',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        Helpers.showErrorSnackBar(context, 'Failed to save reflection');
      }
    }
  }

  Future<List<WeeklyReflection>> _getPastReflections() async {
    try {
      final currentUser = await LocalStorageService.getCurrentUser();
      if (currentUser == null) return [];

      if (!Hive.isBoxOpen('weeklyReflectionsBox')) return [];
      final box = Hive.box<WeeklyReflection>('weeklyReflectionsBox');
      final reflections = box.values
          .where((r) => r.userId == currentUser.id)
          .toList()
        ..sort((a, b) => b.weekStarting.compareTo(a.weekStarting));
      return reflections;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = _currentWeekStart;
    final weekEnd = weekStart.add(Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(weekStart)} \u2013 ${DateFormat('MMM d').format(weekEnd)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Reflection'),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveReflection,
              tooltip: 'Save Reflection',
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // Week header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week of $weekLabel',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Take a moment to reflect on your spending this week.\nThis builds self-awareness and better habits.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Question 1: What went well?
          _buildQuestionCard(
            icon: Icons.celebration_rounded,
            iconColor: Colors.green,
            question: 'What went well?',
            hint: 'e.g. Cooked at home instead of ordering out...',
            controller: _wentWellController,
            theme: theme,
          ),
          SizedBox(height: 20),

          // Question 2: What do you regret?
          _buildQuestionCard(
            icon: Icons.sentiment_dissatisfied_rounded,
            iconColor: Colors.orange,
            question: 'What do you regret?',
            hint: 'e.g. That impulse shopping trip on Wednesday...',
            controller: _regretController,
            theme: theme,
          ),
          SizedBox(height: 20),

          // Question 3: What will you try next week?
          _buildQuestionCard(
            icon: Icons.flag_rounded,
            iconColor: Color(0xFF14B8A6),
            question: 'What will you try next week?',
            hint: 'e.g. Bring lunch to campus instead of buying...',
            controller: _goalController,
            theme: theme,
          ),
          SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveReflection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              _isEditing ? 'Update Reflection' : 'Save Reflection',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 32),

          // Past reflections
          FutureBuilder<List<WeeklyReflection>>(
            future: _getPastReflections(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SizedBox.shrink();
              }
              final reflections = snapshot.data!;
              // Only show past reflections (not current week)
              final pastReflections = reflections.where((r) {
                return r.weekStarting.isBefore(_currentWeekStart);
              }).toList();

              if (pastReflections.isEmpty) return SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Past Reflections',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...pastReflections.take(4).map((r) {
                    final wStart = r.weekStarting;
                    final wEnd = wStart.add(Duration(days: 6));
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('MMM d').format(wStart)} \u2013 ${DateFormat('MMM d').format(wEnd)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF14B8A6),
                            ),
                          ),
                          if (r.wentWell.isNotEmpty) ...[
                            SizedBox(height: 8),
                            _buildReflectionRow(
                              Icons.celebration_rounded,
                              Colors.green,
                              r.wentWell,
                              theme,
                            ),
                          ],
                          if (r.regret.isNotEmpty) ...[
                            SizedBox(height: 6),
                            _buildReflectionRow(
                              Icons.sentiment_dissatisfied_rounded,
                              Colors.orange,
                              r.regret,
                              theme,
                            ),
                          ],
                          if (r.nextWeekGoal.isNotEmpty) ...[
                            SizedBox(height: 6),
                            _buildReflectionRow(
                              Icons.flag_rounded,
                              Color(0xFF14B8A6),
                              r.nextWeekGoal,
                              theme,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required IconData icon,
    required Color iconColor,
    required String question,
    required String hint,
    required TextEditingController controller,
    required ThemeData theme,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              SizedBox(width: 12),
              Text(
                question,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: iconColor, width: 2),
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? theme.scaffoldBackgroundColor
                  : Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionRow(
    IconData icon,
    Color color,
    String text,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
