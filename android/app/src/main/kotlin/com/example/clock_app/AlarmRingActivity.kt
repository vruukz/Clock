package com.example.clock_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import android.graphics.Color
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmRingActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        km.requestDismissKeyguard(this, null)

        val label = intent.getStringExtra("alarm_label") ?: "Alarm"

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(64, 64, 64, 64)
        }

        val timeText = TextView(this).apply {
            text = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
                .format(java.util.Date())
            textSize = 72f
            setTextColor(Color.parseColor("#E8E2D9"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.MONOSPACE
        }

        val labelText = TextView(this).apply {
            text = label
            textSize = 18f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 80)
            typeface = android.graphics.Typeface.MONOSPACE
        }

        val dismissBtn = Button(this).apply {
            text = "DISMISS"
            textSize = 14f
            setTextColor(Color.parseColor("#0D0D0D"))
            setBackgroundColor(Color.parseColor("#C8F060"))
            setPadding(80, 32, 80, 32)
            typeface = android.graphics.Typeface.MONOSPACE
            setOnClickListener { dismiss() }
        }

        layout.addView(timeText)
        layout.addView(labelText)
        layout.addView(dismissBtn)
        setContentView(layout)
    }

    private fun dismiss() {
        // Stop the foreground service which handles sound/vibration
        val stopIntent = Intent(this, AlarmService::class.java)
        stopService(stopIntent)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}