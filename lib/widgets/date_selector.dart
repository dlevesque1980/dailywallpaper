import 'package:flutter/material.dart';
import 'package:dailywallpaper/widgets/date_picker_dialog.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

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
              _formatDate(context, selectedDate),
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

  String _formatDate(BuildContext context, DateTime date) {
    return DateTimeHelper.formatDisplayDate(
      date,
      todayLabel: AppLocalizations.of(context)!.today,
      yesterdayLabel: AppLocalizations.of(context)!.yesterday,
    );
  }

  void _showDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DatePickerDialogCustom(
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
