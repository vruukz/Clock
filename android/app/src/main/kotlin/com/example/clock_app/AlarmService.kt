package com.example.clock_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator

class AlarmService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val label = intent?.getStringExtra("alarm_label") ?: "Alarm"
        val soundPath = intent?.getStringExtra("sound_path")

        createNotificationChannel()

        // Full screen intent to launch AlarmRingActivity
        val ringIntent = Intent(this, AlarmRingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            putExtra("alarm_label", label)
            putExtra("sound_path", soundPath)
            putExtra("service_started", true)
        }

        val fullScreenIntent = PendingIntent.getActivity(
            this, 0, ringIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, AlarmDismissReceiver::class.java)
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this, 0, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, "alarm_foreground")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(label)
            .setContentText("Alarm ringing")
            .setFullScreenIntent(fullScreenIntent, true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_delete,
                "DISMISS",
                dismissPendingIntent
            )
            .build()

        startForeground(1, notification)

        // Start sound
        startSound(soundPath)
        startVibration()

        // Launch the ring activity
        startActivity(ringIntent)

        return START_STICKY
    }

    private fun startSound(soundPath: String?) {
        try {
            mediaPlayer = MediaPlayer().apply {
                val uri = if (soundPath != null) Uri.parse(soundPath)
                          else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(applicationContext, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            try {
                mediaPlayer = MediaPlayer().apply {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .build()
                    )
                    setDataSource(applicationContext, uri)
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (e2: Exception) { }
        }
    }

    private fun startVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        val pattern = longArrayOf(0, 1000, 500, 1000, 500)
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "alarm_foreground",
            "Alarm Service",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            setBypassDnd(true)
            setShowBadge(true)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    fun stopAlarm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }
}