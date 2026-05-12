package com.didisoft.dailywallpaper

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {

    /**
     * Return the pre-warmed engine from [MainApplication] instead of creating a new one.
     * When Android recreates this Activity (e.g., after a Material You dynamic-color change
     * triggered by WallpaperManager), the same Dart isolate reattaches to the new GL surface
     * without restarting. The BLoC tree — including [wallpaperMessage] — survives intact.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return FlutterEngineCache.getInstance().get(MainApplication.ENGINE_ID)
    }
}
