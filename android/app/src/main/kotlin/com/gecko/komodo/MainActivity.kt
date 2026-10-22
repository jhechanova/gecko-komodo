package com.gecko.komodo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "ensure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    LauncherIcon.ensure(applicationContext, call.argument<String>("alias"))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("launcher_icon", e.message, null)
                }
            }
    }

    companion object {
        private const val CHANNEL = "com.gecko.komodo/launcher_icon"
    }
}
