import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:roda/core/theme/roda_colors.dart';

class BirthdayPicker extends StatefulWidget {
  final DateTime? initialDate;
  final Function(DateTime) onDateSelected;
  final String labelText;
  
  const BirthdayPicker({
    super.key,
    this.initialDate,
    required this.onDateSelected,
    this.labelText = 'Date of Birth',
  });
  
  @override
  State<BirthdayPicker> createState() => _BirthdayPickerState();
}

class _BirthdayPickerState extends State<BirthdayPicker> {
  DateTime? _selectedDate;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
  
  Future<void> _selectDate() async {
    // Use platform-specific date picker
    if (Platform.isIOS) {
      await _showIOSDatePicker();
    } else {
      await _showMaterialDatePicker();
    }
  }
  
  Future<void> _showIOSDatePicker() async {
    DateTime tempDate = _selectedDate ?? DateTime(2000, 1, 1);
    
    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: RodaColors.systemBackground,
          child: Column(
            children: [
              // Header with Done button
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: RodaColors.systemGrey6,
                  border: Border(
                    bottom: BorderSide(color: RodaColors.systemGrey4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    Text(
                      'Select Birthday',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: RodaColors.label,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = tempDate;
                        });
                        widget.onDateSelected(tempDate);
                        Navigator.pop(context);
                        // Unfocus to prevent jumping to random field
                        FocusScope.of(context).unfocus();
                      },
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              // Date Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? DateTime(2000, 1, 1),
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _showMaterialDatePicker() async {
    // Custom Material date picker with better UX
    final DateTime? picked = await showCupertinoDialog<DateTime>(
      context: context,
      builder: (context) => _CustomDatePickerDialog(
        initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      ),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      widget.onDateSelected(picked);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: RodaColors.systemGrey4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.labelText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: RodaColors.label,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate != null
                      ? _formatDate(_selectedDate!)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null 
                        ? RodaColors.label
                        : RodaColors.secondaryLabel,
                  ),
                ),
                if (_selectedDate != null)
                  Text(
                    'Age: ${_calculateAge(_selectedDate!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: RodaColors.secondaryLabel,
                    ),
                  ),
                const Icon(CupertinoIcons.calendar, color: RodaColors.systemGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Material Date Picker Dialog with better UX
class _CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  
  const _CustomDatePickerDialog({
    required this.initialDate,
  });
  
  @override
  State<_CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<_CustomDatePickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;
  
  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    selectedDay = widget.initialDate.day;
  }
  
  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      // February - check for leap year
      if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
        return 29;
      }
      return 28;
    } else if ([4, 6, 9, 11].contains(month)) {
      return 30;
    }
    return 31;
  }
  
  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > daysInMonth) {
      selectedDay = daysInMonth;
    }
    
    return CupertinoAlertDialog(
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Birthday',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            
            // Year Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Year',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RodaColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: RodaColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: DateTime.now().year - 1900 + 1,
                    itemBuilder: (context, index) {
                      final year = DateTime.now().year - index;
                      final isSelected = year == selectedYear;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedYear = year;
                          });
                        },
                        child: Container(
                          width: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? RodaColors.activeBlue 
                                : RodaColors.systemBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            year.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? RodaColors.white : RodaColors.label,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Month Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Month',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RodaColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final isSelected = month == selectedMonth;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMonth = month;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? RodaColors.activeBlue 
                                : RodaColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? RodaColors.activeBlue 
                                  : RodaColors.systemGrey4,
                            ),
                          ),
                          child: Text(
                            months[index].substring(0, 3),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? RodaColors.white : RodaColors.label,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Day Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RodaColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: daysInMonth,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isSelected = day == selectedDay;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDay = day;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? RodaColors.activeBlue 
                                : RodaColors.systemBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? RodaColors.activeBlue 
                                  : RodaColors.systemGrey4,
                            ),
                          ),
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? RodaColors.white : RodaColors.label,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Selected Date Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RodaColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.gift, size: 20, color: RodaColors.systemGrey),
                  const SizedBox(width: 8),
                  Text(
                    '${months[selectedMonth - 1]} $selectedDay, $selectedYear',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                  onPressed: () {
                    final selected = DateTime(selectedYear, selectedMonth, selectedDay);
                    Navigator.pop(context, selected);
                    // Unfocus to prevent jumping to random field
                    FocusScope.of(context).unfocus();
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}