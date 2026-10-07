package ru.zamer.zamer_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                ZamerFilamentViewFactory.viewType,
                ZamerFilamentViewFactory(flutterEngine.dartExecutor.binaryMessenger),
            )
    }
}
