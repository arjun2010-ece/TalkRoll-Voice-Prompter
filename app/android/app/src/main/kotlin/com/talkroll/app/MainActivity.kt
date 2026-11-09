package com.talkroll.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speech: SpeechChannel? = null
    private var transcriber: FileTranscriberChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speech = SpeechChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        transcriber = FileTranscriberChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speech?.dispose()
        speech = null
        transcriber?.dispose()
        transcriber = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
