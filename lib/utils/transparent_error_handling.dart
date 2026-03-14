import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Utility class for handling errors transparently without blocking the UI
///
/// This class provides methods to handle various types of errors gracefully,
/// ensuring the user experience remains smooth even when technical issues occur.
class TransparentErrorHandling {
  /// Handle Smart Crop related errors transparently
  ///
  /// Logs the error for debugging but doesn't notify the user.
  /// Can optionally perform fallback actions.
  static Future<void> handleSmartCropError(
    dynamic error, {
    VoidCallback? fallbackAction,
  }) async {
    if (kDebugMode) {
      debugPrint('Smart Crop error (handled transparently): $error');
    }

    // Execute fallback action if provided
    if (fallbackAction != null) {
      try {
        fallbackAction();
      } catch (fallbackError) {
        if (kDebugMode) {
          debugPrint('Fallback action failed: $fallbackError');
        }
      }
    }
  }

  /// Handle loading errors in widgets
  ///
  /// Returns appropriate widgets based on the snapshot state,
  /// avoiding persistent loading indicators.
  static Widget? handleLoadingError<T>(
    AsyncSnapshot<T> snapshot, {
    Widget? errorWidget,
    Widget? loadingWidget,
    bool showLoadingOnWaiting = false,
  }) {
    if (snapshot.hasError) {
      if (kDebugMode) {
        debugPrint(
            'Widget loading error (handled transparently): ${snapshot.error}');
      }
      // Return error widget or empty container instead of showing error to user
      return errorWidget ?? Container();
    }

    if (snapshot.connectionState == ConnectionState.none) {
      // No connection established, return empty container
      return Container();
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      // Only show loading if explicitly requested and data is not available
      if (showLoadingOnWaiting && !snapshot.hasData) {
        return loadingWidget ??
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
      }
      // If we have data, use it even while waiting for updates
      if (snapshot.hasData) {
        return null; // Let the builder handle the data
      }
      // No data and not showing loading, return empty container
      return Container();
    }

    // Connection is active or done, let the builder handle it
    return null;
  }

  /// Handle network-related errors
  static Future<void> handleNetworkError(
    dynamic error, {
    VoidCallback? retryAction,
  }) async {
    if (kDebugMode) {
      debugPrint('Network error (handled transparently): $error');
    }

    // Could implement retry logic here if needed
    if (retryAction != null) {
      // Add a small delay before retry
      await Future.delayed(Duration(milliseconds: 500));
      try {
        retryAction();
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint('Retry action failed: $retryError');
        }
      }
    }
  }

  /// Handle cache-related errors
  static Future<void> handleCacheError(
    dynamic error, {
    VoidCallback? clearCacheAction,
  }) async {
    if (kDebugMode) {
      debugPrint('Cache error (handled transparently): $error');
    }

    // Optionally clear cache on error
    if (clearCacheAction != null) {
      try {
        clearCacheAction();
      } catch (clearError) {
        if (kDebugMode) {
          debugPrint('Cache clear action failed: $clearError');
        }
      }
    }
  }

  /// Handle configuration errors
  static Future<T> handleConfigurationError<T>(
    Future<T> Function() action,
    T defaultValue, {
    String? errorContext,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (kDebugMode) {
        final context = errorContext ?? 'Configuration';
        debugPrint('$context error (handled transparently): $error');
      }
      return defaultValue;
    }
  }

  /// Create a safe FutureBuilder that handles errors transparently
  static Widget safeFutureBuilder<T>({
    required Future<T>? future,
    required Widget Function(BuildContext context, T data) builder,
    T? initialData,
    Widget? loadingWidget,
    Widget? errorWidget,
    bool showLoadingOnWaiting = false,
  }) {
    return FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        final errorResult = handleLoadingError(
          snapshot,
          errorWidget: errorWidget,
          loadingWidget: loadingWidget,
          showLoadingOnWaiting: showLoadingOnWaiting,
        );

        if (errorResult != null) {
          return errorResult;
        }

        // We have data, use it
        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        // Fallback to empty container
        return Container();
      },
    );
  }

  /// Create a safe StreamBuilder that handles errors transparently
  static Widget safeStreamBuilder<T>({
    required Stream<T>? stream,
    required Widget Function(BuildContext context, T data) builder,
    T? initialData,
    Widget? loadingWidget,
    Widget? errorWidget,
    bool showLoadingOnWaiting = false,
  }) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        final errorResult = handleLoadingError(
          snapshot,
          errorWidget: errorWidget,
          loadingWidget: loadingWidget,
          showLoadingOnWaiting: showLoadingOnWaiting,
        );

        if (errorResult != null) {
          return errorResult;
        }

        // We have data, use it
        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        // Fallback to empty container
        return Container();
      },
    );
  }
}
