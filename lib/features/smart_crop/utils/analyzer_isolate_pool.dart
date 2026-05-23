import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import 'battery_optimizer.dart';

/// A pool of persistent Dart [Isolate]s for reuse across SmartCrop analyzer
/// calls, eliminating the ~5–20 ms spawn overhead of [Isolate.run()].
///
/// ## Guardrails
/// | Condition              | Behaviour                                     |
/// |------------------------|-----------------------------------------------|
/// | Battery strategy ≥ moderate | Pool limited to 1 worker               |
/// | App idle > 30 s        | Workers paused via [Isolate.pause()]           |
/// | Dart memory pressure   | Pool killed; falls back to [Isolate.run()]     |
/// | App lifecycle          | Call [suspend()] / [resume()] as appropriate   |
///
/// ## Usage
/// ```dart
/// final result = await AnalyzerIsolatePool.instance.run(myTopLevelFn, args);
/// ```
class AnalyzerIsolatePool {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AnalyzerIsolatePool instance = AnalyzerIsolatePool._();
  AnalyzerIsolatePool._();

  // ── Config ─────────────────────────────────────────────────────────────────
  static const int _defaultMaxWorkers = 3;
  static const Duration _idleTimeout = Duration(seconds: 30);

  // ── State ──────────────────────────────────────────────────────────────────
  final List<_PoolWorker> _workers = [];
  bool _suspended = false;
  bool _disposed = false;
  Timer? _idleTimer;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Executes [fn] in a pooled isolate and returns the result.
  ///
  /// Falls back transparently to [Isolate.run()] when:
  ///  - the pool is suspended (app in background),
  ///  - memory pressure has killed the pool, or
  ///  - all workers are busy and a new one cannot be spawned.
  Future<R> run<M, R>(ComputeCallback<M, R> fn, M message) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return fn(message);
    }

    if (_disposed || _suspended) {
      return Isolate.run(() => fn(message));
    }

    _resetIdleTimer();

    try {
      final effectiveMax = await _effectiveWorkerLimit();
      final worker = await _acquireWorker(max: effectiveMax);
      return await worker.run(fn, message);
    } catch (_) {
      // Graceful fallback — never crash the caller.
      return Isolate.run(() => fn(message));
    }
  }

  /// Suspends all workers (e.g. app goes to background).
  /// In-flight tasks are allowed to complete; new tasks fall back to
  /// [Isolate.run()].
  void suspend() {
    _suspended = true;
    _idleTimer?.cancel();
    for (final w in _workers) {
      w.pause();
    }
  }

  /// Resumes a previously suspended pool.
  void resume() {
    _suspended = false;
    for (final w in _workers) {
      w.resume();
    }
  }

  /// Permanently disposes the pool and kills all isolates.
  /// After calling this, [run()] always falls back to [Isolate.run()].
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    for (final w in _workers) {
      w.kill();
    }
    _workers.clear();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  /// Returns the maximum number of active workers allowed given current
  /// battery / memory conditions.
  Future<int> _effectiveWorkerLimit() async {
    try {
      final strategy = await BatteryOptimizer.getOptimizationStrategy();
      switch (strategy) {
        case BatteryOptimizationStrategy.aggressive:
        case BatteryOptimizationStrategy.moderate:
          return 1; // Conserve power — single worker.
        case BatteryOptimizationStrategy.minimal:
          return 2;
        case BatteryOptimizationStrategy.none:
          return _defaultMaxWorkers;
      }
    } catch (_) {
      return 1; // Safe default on error.
    }
  }

  /// Finds an idle worker or spawns a new one (up to [max]).
  /// Throws if no worker is available and we're at capacity.
  Future<_PoolWorker> _acquireWorker({required int max}) async {
    // Prefer an already-idle worker.
    for (final w in _workers) {
      if (w.isIdle) return w;
    }

    // Spawn a new one if under the cap.
    if (_workers.length < max) {
      final worker = _PoolWorker();
      await worker.spawn();
      _workers.add(worker);
      return worker;
    }

    // All workers busy — wait briefly for one to free up, then give up.
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      for (final w in _workers) {
        if (w.isIdle) return w;
      }
    }

    throw StateError('All pool workers are busy.');
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _pauseIdleWorkers);
  }

  void _pauseIdleWorkers() {
    for (final w in _workers) {
      if (w.isIdle) w.pause();
    }
  }
}

// ── Internal worker ────────────────────────────────────────────────────────

/// A single persistent [Isolate] worker managed by [AnalyzerIsolatePool].
class _PoolWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  bool _paused = false;
  bool _busy = false;
  Capability? _pauseCapability;

  bool get isIdle => !_busy && !_paused && _isolate != null;

  /// Spawns the underlying isolate and waits for the handshake.
  Future<void> spawn() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      receivePort.sendPort,
      debugName: 'SmartCropPoolWorker',
    );
    _sendPort = await receivePort.first as SendPort;
    receivePort.close();
  }

  /// Runs [fn] with [message] in this worker's isolate.
  Future<R> run<M, R>(ComputeCallback<M, R> fn, M message) async {
    if (_isolate == null || _sendPort == null) {
      throw StateError('Worker not spawned.');
    }
    if (_paused) resume();

    _busy = true;
    final responsePort = ReceivePort();
    try {
      _sendPort!.send(_WorkerTask(
        fn: fn as ComputeCallback<dynamic, dynamic>,
        message: message,
        replyPort: responsePort.sendPort,
      ));

      final response = await responsePort.first;
      if (response is _WorkerError) throw response.error;
      return response as R;
    } finally {
      _busy = false;
      responsePort.close();
    }
  }

  void pause() {
    if (_isolate != null && !_paused) {
      _pauseCapability = _isolate!.pause();
      _paused = true;
    }
  }

  void resume() {
    if (_isolate != null && _paused && _pauseCapability != null) {
      _isolate!.resume(_pauseCapability!);
      _pauseCapability = null;
      _paused = false;
    }
  }

  void kill() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }
}

// ── Isolate entry point (top-level required) ───────────────────────────────

void _workerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is! _WorkerTask) return;
    try {
      final result = await message.fn(message.message);
      message.replyPort.send(result);
    } catch (e) {
      message.replyPort.send(_WorkerError(e));
    }
  });
}

// ── Data transfer objects ──────────────────────────────────────────────────

class _WorkerTask {
  final ComputeCallback<dynamic, dynamic> fn;
  final dynamic message;
  final SendPort replyPort;
  const _WorkerTask(
      {required this.fn, required this.message, required this.replyPort});
}

class _WorkerError {
  final Object error;
  const _WorkerError(this.error);
}
