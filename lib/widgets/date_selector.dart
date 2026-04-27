import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final List<DateTime> availableDates;
  final Function(DateTime) onDateSelected;
  final bool isLoading;

  const DateSelector({
    Key? key,
    required this.selectedDate,
    required this.availableDates,
    required this.onDateSelected,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => _showDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 16.0,
              shadows: [
                Shadow(
                  offset: const Offset(1.0, 1.0),
                  blurRadius: 3.0,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(width: 8.0),
            Text(
              _formatDate(selectedDate),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: const Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8.0),
              SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ] else ...[
              const SizedBox(width: 4.0),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
                size: 20.0,
                shadows: [
                  Shadow(
                    offset: const Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  void _showDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _DatePickerDialog(
          selectedDate: selectedDate,
          availableDates: availableDates,
          onDateSelected: (date) {
            Navigator.of(context).pop();
            onDateSelected(date);
          },
        );
      },
    );
  }
}

class _DatePickerDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<DateTime> availableDates;
  final Function(DateTime) onDateSelected;

  const _DatePickerDialog({
    Key? key,
    required this.selectedDate,
    required this.availableDates,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  _DatePickerDialogState createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _currentMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildCalendar(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _canNavigateToPreviousMonth() ? _previousMonth : null,
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM y').format(_currentMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _canNavigateToNextMonth() ? _nextMonth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildWeekdayHeaders(),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildDaysGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayWeekday =
        firstDayOfMonth.weekday % 7; // Convert to 0-6 (Sun-Sat)

    final days = <Widget>[];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDayWeekday; i++) {
      days.add(Container());
    }

    // Add days of the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      days.add(_buildDayCell(date));
    }

    return GridView.count(
      crossAxisCount: 7,
      children: days,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isAvailable = _isDateAvailable(date);
    final isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: isAvailable ? () => widget.onDateSelected(date) : null,
      child: Container(
        margin: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : isToday
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: isAvailable
              ? Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  width: 1.0,
                )
              : null,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                date.day.toString(),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isAvailable
                          ? Colors.black87
                          : Colors.grey[400],
                  fontSize: 14.0,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (isAvailable && !isSelected)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isDateAvailable(DateTime date) {
    return widget.availableDates
        .any((availableDate) => _isSameDay(date, availableDate));
  }

  bool _canNavigateToPreviousMonth() {
    if (widget.availableDates.isEmpty) return false;

    final earliestDate =
        widget.availableDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);

    // Allow navigation if the previous month is not before the earliest available date's month
    return previousMonth.year > earliestDate.year ||
        (previousMonth.year == earliestDate.year &&
            previousMonth.month >= earliestDate.month);
  }

  bool _canNavigateToNextMonth() {
    if (widget.availableDates.isEmpty) return false;

    final latestDate =
        widget.availableDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);

    // Allow navigation if the next month is not after the latest available date's month
    return nextMonth.year < latestDate.year ||
        (nextMonth.year == latestDate.year &&
            nextMonth.month <= latestDate.month);
  }

  void _previousMonth() {
    if (_canNavigateToPreviousMonth()) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      });
    }
  }

  void _nextMonth() {
    if (_canNavigateToNextMonth()) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
    }
  }
}
