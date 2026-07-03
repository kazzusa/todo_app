package com.personal.todo_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.personal.todo_app/widget"
    private var methodChannel: MethodChannel? = null
    private var pendingOpenAdd = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        TodoWidgetProvider.updateAllWidgets(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == "ADD_TASK") pendingOpenAdd = true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "ADD_TASK") {
            methodChannel?.invokeMethod("openAddTask", null)
        }
    }

    override fun onResume() {
        super.onResume()
        if (pendingOpenAdd) {
            pendingOpenAdd = false
            methodChannel?.invokeMethod("openAddTask", null)
        }
    }
}
