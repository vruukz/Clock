package com.example.clock_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "clock_app:AlarmWakeLock"
        )
        wl.acquire(60000)

        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("alarm_label", intent.getStringExtra("alarm_label") ?: "Alarm")
            putExtra("sound_path", intent.getStringExtra("sound_path"))
        }
        context.startForegroundService(serviceIntent)
    }
}