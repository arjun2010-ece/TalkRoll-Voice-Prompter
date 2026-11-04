package com.echoprompter.echoprompter_camera

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** Keeps the camera (and the microphone, unless the take is a Narration take) alive while the app is recording. */
class RecordingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel("recording", "Recording", NotificationManager.IMPORTANCE_LOW))
        }
        val n = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "recording") else Notification.Builder(this))
            .setContentTitle("EchoPrompter is recording")
            .setSmallIcon(android.R.drawable.presence_video_online)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            val withMic = intent?.getBooleanExtra("withMic", true) ?: true
            val type = if (withMic) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            else ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            startForeground(1, n, type)
        } else {
            startForeground(1, n)
        }
        return START_NOT_STICKY
    }
}
