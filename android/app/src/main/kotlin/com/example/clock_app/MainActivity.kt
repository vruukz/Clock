package com.example.clock_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.clock_app/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val triggerTime = call.argument<Long>("triggerTime") ?: 0L
                    val label = call.argument<String>("label") ?: "Alarm"
                    val soundPath = call.argument<String>("soundPath")
                    scheduleAlarm(id, triggerTime, label, soundPath)
                    result.success(null)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelAlarm(id)
                    result.success(null)
                }
                "requestBatteryOptimization" -> {
    val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = android.net.Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
    result.success(null)
}
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAlarm(id: Int, triggerTime: Long, label: String, soundPath: String?) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("alarm_label", label)
            putExtra("alarm_id", id.toString())
            putExtra("sound_path", soundPath)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Show intent for status bar alarm icon
        val showIntent = Intent(this, MainActivity::class.java)
        val showPendingIntent = PendingIntent.getActivity(
            this, id, showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // setAlarmClock is the ONLY method guaranteed to fire after app kill
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerTime, showPendingIntent),
            pendingIntent
        )
    }

    private fun cancelAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }
}