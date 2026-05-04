import 'package:flutter/material.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_profile_manager.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

/// Custom slider widget for Smart Crop quality selection
///
/// Provides 4 discrete positions: Off, Conservative, Balanced, Aggressive
/// with color-coded levels and dynamic descriptions.
class SmartCropQualitySlider extends StatefulWidget {
  /// Current quality level (0-3)
  final int currentLevel;

  /// Callback when level changes
  final Function(int level) onLevelChanged;

  /// Whether the slider is enabled
  final bool enabled;
  
  /// Subject scaling enabled
  final bool subjectScalingEnabled;
  
  /// Callback when scaling toggled
  final Function(bool value) onScalingToggled;

  const SmartCropQualitySlider({
    Key? key,
    required this.currentLevel,
    required this.onLevelChanged,
    required this.subjectScalingEnabled,
    required this.onScalingToggled,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<SmartCropQualitySlider> createState() => _SmartCropQualitySliderState();
}

class _SmartCropQualitySliderState extends State<SmartCropQualitySlider> {
  late int _currentLevel;
  bool _isChanging = false;

  /// Colors for each quality level
  static const Map<int, Color> _levelColors = {
    0: Colors.grey, // Off - Grey
    1: Colors.green, // Conservative - Green
    2: Colors.blue, // Balanced - Blue
    3: Colors.orange, // Aggressive - Orange
  };

  /// Labels for each position
  static const List<String> _labels = [
    'Off',
    'Conservative',
    'Balanced',
    'Aggressive'
  ];

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.currentLevel.clamp(0, 3);
  }

  @override
  void didUpdateWidget(SmartCropQualitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLevel != oldWidget.currentLevel) {
      setState(() {
        _currentLevel = widget.currentLevel.clamp(0, 3);
      });
    }
  }

  /// Gets the current level color
  Color get _currentColor => _levelColors[_currentLevel] ?? Colors.grey;

  /// Gets the current level description
  String _getCurrentDescription(BuildContext context) {
     // Ideally, these should be in AppLocalizations too, but they are in ProfileManager for now.
     // We will leave them there but we could localize them later.
     return SmartCropProfileManager.getLevelDescription(_currentLevel);
  }

  /// Handles slider value change
  void _onSliderChanged(double value) {
    final newLevel = value.round().clamp(0, 3);
    if (newLevel != _currentLevel && !_isChanging) {
      setState(() {
        _currentLevel = newLevel;
        _isChanging = true;
      });
    }
  }

  /// Handles slider change end - applies the new level
  void _onSliderChangeEnd(double value) {
    final newLevel = value.round().clamp(0, 3);

    if (newLevel != widget.currentLevel) {
      widget.onLevelChanged(newLevel);
    }

    setState(() {
      _isChanging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Smart Crop Quality',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),

        // Slider container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _currentColor.withValues(alpha: 0.3),
              width: 2.0,
            ),
          ),
          child: Column(
            children: [
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _currentColor,
                  inactiveTrackColor: _currentColor.withValues(alpha: 0.3),
                  thumbColor: _currentColor,
                  overlayColor: _currentColor.withValues(alpha: 0.2),
                  valueIndicatorColor: _currentColor,
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                ),
                child: Slider(
                  value: _currentLevel.toDouble(),
                  min: 0.0,
                  max: 3.0,
                  divisions: 3,
                  onChanged: widget.enabled ? _onSliderChanged : null,
                  onChangeEnd: widget.enabled ? _onSliderChangeEnd : null,
                ),
              ),

              // Labels row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _labels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final label = entry.value;
                    final isSelected = index == _currentLevel;
                    final color = _levelColors[index] ?? Colors.grey;

                    return Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected ? color : Colors.grey,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 11.0,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12.0),

              // Current level indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _currentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: _currentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current level name with color indicator
                    Row(
                      children: [
                        Container(
                          width: 12.0,
                          height: 12.0,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          SmartCropProfileManager.getLevelLabel(_currentLevel),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _currentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (_isChanging) ...[
                          const SizedBox(width: 8.0),
                          SizedBox(
                            width: 12.0,
                            height: 12.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation(_currentColor),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4.0),

                    // Description
                    Text(
                      _getCurrentDescription(context),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              
              // Subject scaling toggle
              if (_currentLevel > 0)
                SwitchListTile(
                  title: Text(
                    'Zoom auto pour préserver le sujet', // TODO: Localize
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(
                    "Si le sujet principal est trop grand pour le cadre, zoom arrière pour l'inclure entièrement.", // TODO: Localize
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                  ),
                  value: widget.subjectScalingEnabled,
                  onChanged: widget.enabled ? widget.onScalingToggled : null,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _currentColor,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
