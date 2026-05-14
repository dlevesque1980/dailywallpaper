import 'dart:ui' as ui;
import '../interfaces/crop_analyzer.dart';

import '../models/crop_settings.dart';

/// Exception thrown when analyzer registration fails
class AnalyzerRegistrationException implements Exception {
  final String message;
  final String? analyzerName;

  const AnalyzerRegistrationException(this.message, [this.analyzerName]);

  @override
  String toString() =>
      'AnalyzerRegistrationException: $message${analyzerName != null ? ' (analyzer: $analyzerName)' : ''}';
}

/// Exception thrown when analyzer validation fails
class AnalyzerValidationException implements Exception {
  final String message;
  final String analyzerName;
  final List<String> validationErrors;

  const AnalyzerValidationException(
      this.message, this.analyzerName, this.validationErrors);

  @override
  String toString() =>
      'AnalyzerValidationException: $message (analyzer: $analyzerName, errors: ${validationErrors.join(', ')})';
}

/// Registry for managing crop analyzer plugins
class AnalyzerRegistry {
  static final AnalyzerRegistry _instance = AnalyzerRegistry._internal();
  factory AnalyzerRegistry() => _instance;
  AnalyzerRegistry._internal();

  final Map<String, CropAnalyzer> _analyzers = {};
  final Map<String, bool> _enabledAnalyzers = {};
  final Map<String, DateTime> _registrationTimes = {};
  final Map<String, int> _usageCount = {};
  final List<String> _loadOrder = [];

  /// Registers a new crop analyzer
  void registerAnalyzer(CropAnalyzer analyzer) {
    final name =
        analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;

    // Validate analyzer
    final validationErrors = _validateAnalyzer(analyzer);
    if (validationErrors.isNotEmpty) {
      throw AnalyzerValidationException(
        'Analyzer validation failed',
        name,
        validationErrors,
      );
    }

    // Check for conflicts with existing analyzers
    _checkConflicts(analyzer);

    // Check dependencies
    _checkDependencies(analyzer);

    // Register the analyzer
    _analyzers[name] = analyzer;
    _enabledAnalyzers[name] = analyzer.isEnabledByDefault;
    _registrationTimes[name] = DateTime.now();
    _usageCount[name] = 0;

    if (!_loadOrder.contains(name)) {
      _loadOrder.add(name);
    }
  }

  /// Unregisters an analyzer
  bool unregisterAnalyzer(String name) {
    if (!_analyzers.containsKey(name)) {
      return false;
    }

    // Check if other analyzers depend on this one
    final dependents = _findDependents(name);
    if (dependents.isNotEmpty) {
      throw AnalyzerRegistrationException(
        'Cannot unregister analyzer because other analyzers depend on it: ${dependents.join(', ')}',
        name,
      );
    }

    // Dispose the analyzer (only for v2 analyzers)
    final analyzer = _analyzers[name];
    if (analyzer is CropAnalyzerV2) {
      analyzer.dispose();
    }

    // Remove from all tracking maps
    _analyzers.remove(name);
    _enabledAnalyzers.remove(name);
    _registrationTimes.remove(name);
    _usageCount.remove(name);
    _loadOrder.remove(name);

    return true;
  }

  /// Gets an analyzer by name
  CropAnalyzer? getAnalyzer(String name) {
    return _analyzers[name];
  }

  /// Gets all registered analyzers
  List<CropAnalyzer> getAllAnalyzers() {
    return _analyzers.values.toList();
  }

  /// Gets enabled analyzers sorted by priority
  List<CropAnalyzer> getEnabledAnalyzers(
      {CropSettings? settings, ui.Image? image}) {
    final enabled = _analyzers.entries
        .where((entry) => _enabledAnalyzers[entry.key] == true)
        .map((entry) => entry.value)
        .where((analyzer) {
      // Additional filtering based on settings and image
      if (settings != null && image != null) {
        // Use v2 canAnalyze method if available, otherwise assume compatible
        if (analyzer is CropAnalyzerV2) {
          return analyzer.canAnalyze(image, settings);
        }
        return true;
      }
      return true;
    }).toList();

    // Sort by priority (higher priority first)
    // V2 analyzers have priority, v1 analyzers default to 100
    enabled.sort((a, b) {
      final aPriority = a is CropAnalyzerV2 ? a.priority : 100;
      final bPriority = b is CropAnalyzerV2 ? b.priority : 100;
      return bPriority.compareTo(aPriority);
    });

    return enabled;
  }

  /// Enables or disables an analyzer
  void setAnalyzerEnabled(String name, bool enabled) {
    if (!_analyzers.containsKey(name)) {
      throw AnalyzerRegistrationException('Analyzer not found: $name');
    }
    _enabledAnalyzers[name] = enabled;
  }

  /// Checks if an analyzer is enabled
  bool isAnalyzerEnabled(String name) {
    return _enabledAnalyzers[name] ?? false;
  }

  /// Gets analyzers that can handle the given image and settings
  List<CropAnalyzer> getCompatibleAnalyzers(
      ui.Image image, CropSettings settings) {
    return getEnabledAnalyzers(settings: settings, image: image)
        .where((analyzer) {
      // Use v2 canAnalyze method if available, otherwise assume compatible
      if (analyzer is CropAnalyzerV2) {
        return analyzer.canAnalyze(image, settings);
      }
      return true;
    }).toList();
  }

  /// Records usage of an analyzer
  void recordUsage(String name) {
    if (_usageCount.containsKey(name)) {
      _usageCount[name] = _usageCount[name]! + 1;
    }
  }

  /// Gets registry statistics
  Map<String, dynamic> getStats() {
    return {
      'total_analyzers': _analyzers.length,
      'enabled_analyzers': _enabledAnalyzers.values.where((e) => e).length,
      'disabled_analyzers': _enabledAnalyzers.values.where((e) => !e).length,
      'load_order': List.from(_loadOrder),
      'usage_counts': Map.from(_usageCount),
      'registration_times':
          _registrationTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  /// Validates analyzer dependencies and enables/disables accordingly
  void validateDependencies() {
    for (final analyzer in _analyzers.values) {
      final analyzerName =
          analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;
      if (_enabledAnalyzers[analyzerName] == true) {
        // Check if all dependencies are enabled (only for v2 analyzers)
        if (analyzer is CropAnalyzerV2) {
          for (final dependency in analyzer.metadata.dependencies) {
            if (_enabledAnalyzers[dependency] != true) {
              // Disable this analyzer if dependency is not enabled
              _enabledAnalyzers[analyzerName] = false;
              break;
            }
          }
        }
      }
    }
  }

  /// Clears all registered analyzers
  void clear() {
    // Dispose all analyzers (only v2 analyzers)
    for (final analyzer in _analyzers.values) {
      if (analyzer is CropAnalyzerV2) {
        analyzer.dispose();
      }
    }

    _analyzers.clear();
    _enabledAnalyzers.clear();
    _registrationTimes.clear();
    _usageCount.clear();
    _loadOrder.clear();
  }

  /// Validates an analyzer before registration
  List<String> _validateAnalyzer(CropAnalyzer analyzer) {
    final errors = <String>[];

    // Check basic validation (only for v2 analyzers)
    if (analyzer is CropAnalyzerV2 && !analyzer.validate()) {
      errors.add('Analyzer failed basic validation');
    }

    // Check name
    final analyzerName =
        analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;
    if (analyzerName.isEmpty) {
      errors.add('Analyzer name cannot be empty');
    }

    // Check for duplicate names
    if (_analyzers.containsKey(analyzerName)) {
      errors.add('Analyzer with name "$analyzerName" already registered');
    }

    // Check priority (only for v2 analyzers)
    if (analyzer is CropAnalyzerV2 && analyzer.priority < 0) {
      errors.add('Priority must be non-negative');
    }

    // Check weight
    if (analyzer.weight < 0.0 || analyzer.weight > 1.0) {
      errors.add('Weight must be between 0.0 and 1.0');
    }

    // Check metadata (only for v2 analyzers)
    if (analyzer is CropAnalyzerV2) {
      if (analyzer.metadata.description.isEmpty) {
        errors.add('Analyzer description cannot be empty');
      }

      if (analyzer.metadata.version.isEmpty) {
        errors.add('Analyzer version cannot be empty');
      }
    }

    return errors;
  }

  /// Checks for conflicts with existing analyzers
  void _checkConflicts(CropAnalyzer analyzer) {
    // Only check conflicts for v2 analyzers
    if (analyzer is CropAnalyzerV2) {
      for (final existingAnalyzer in _analyzers.values) {
        if (existingAnalyzer is CropAnalyzerV2) {
          if (existingAnalyzer.metadata.hasConflictWith(analyzer.name) ||
              analyzer.metadata.hasConflictWith(existingAnalyzer.name)) {
            throw AnalyzerRegistrationException(
              'Analyzer "${analyzer.name}" conflicts with existing analyzer "${existingAnalyzer.name}"',
              analyzer.name,
            );
          }
        }
      }
    }
  }

  /// Checks if all dependencies are available
  void _checkDependencies(CropAnalyzer analyzer) {
    // Only check dependencies for v2 analyzers
    if (analyzer is CropAnalyzerV2) {
      for (final dependency in analyzer.metadata.dependencies) {
        if (!_analyzers.containsKey(dependency)) {
          throw AnalyzerRegistrationException(
            'Dependency "$dependency" not found for analyzer "${analyzer.name}"',
            analyzer.name,
          );
        }
      }
    }
  }

  /// Finds analyzers that depend on the given analyzer
  List<String> _findDependents(String analyzerName) {
    final dependents = <String>[];

    for (final analyzer in _analyzers.values) {
      // Only check dependencies for v2 analyzers
      if (analyzer is CropAnalyzerV2 &&
          analyzer.metadata.dependsOn(analyzerName)) {
        dependents.add(analyzer.name);
      }
    }

    return dependents;
  }
}
