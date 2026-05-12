package com.didisoft.dailywallpaper

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Custom Application class that pre-warms a [FlutterEngine] before any Activity starts.
 *
 * Problem: applying a wallpaper via [android.app.WallpaperManager] triggers Material You to
 * regenerate its dynamic-color frro resources. Android detects the `assetsPaths` configuration
 * change (which cannot be listed in android:configChanges via XML) and forcibly recreates
 * MainActivity. Without a cached engine this restarts the Dart VM, producing a visible
 * "screen refresh" of ~300-500 ms.
 *
 * Solution: by caching the engine here, MainActivity reattaches to the running Dart isolate
 * on every recreate. Only the GL surface is rebuilt (~50 ms), making the transition
 * virtually imperceptible to the user.
 */
class MainApplication : Application() {

    companion object {
        const val ENGINE_ID = "main_engine"
    }

    override fun onCreate() {
        super.onCreate()

        val engine = FlutterEngine(this)

        // Register all Flutter plugins (channel handlers) before Dart code runs.
        GeneratedPluginRegistrant.registerWith(engine)

        // Start the Dart entrypoint — this keeps the Dart isolate alive independently
        // of the Activity lifecycle, so BLoC state (including wallpaperMessage) survives
        // the Material You Activity restart.
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
