package com.example.azaan_ramzan_timings

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class AlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show on lock screen + turn screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val prayerName = intent.getStringExtra("prayer_name") ?: "Prayer"

        val rootLayout = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0D1117"))
        }

        val centerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
        }

        val iconText = TextView(this).apply {
            text = "🕌"
            textSize = 80f
            gravity = android.view.Gravity.CENTER
        }
        val iconParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = 32 }
        centerLayout.addView(iconText, iconParams)

        val nameText = TextView(this).apply {
            text = "$prayerName Prayer"
            textSize = 48f
            setTextColor(Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        val nameParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = 16 }
        centerLayout.addView(nameText, nameParams)

        val statusText = TextView(this).apply {
            text = "It's time to pray!"
            textSize = 24f
            setTextColor(Color.parseColor("#C9A84C"))
            gravity = android.view.Gravity.CENTER
        }
        val statusParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = 48 }
        centerLayout.addView(statusText, statusParams)

        val dismissButton = Button(this).apply {
            text = "🔇 Dismiss Alarm"
            textSize = 18f
            setTextColor(Color.BLACK)
            setBackgroundColor(Color.parseColor("#C9A84C"))
            isAllCaps = false
            setOnClickListener {
                val stopFg = Intent(this@AlarmActivity, AzanForegroundService::class.java).apply {
                    action = AzanForegroundService.ACTION_STOP_ALARM
                }
                startService(stopFg)

                val stopPb = Intent(this@AlarmActivity, AzanPlaybackService::class.java).apply {
                    action = AzanPlaybackService.ACTION_STOP
                }
                startService(stopPb)

                finish()
            }
        }
        val buttonParams = LinearLayout.LayoutParams(
            (resources.displayMetrics.widthPixels * 0.8).toInt(), 144
        )
        centerLayout.addView(dismissButton, buttonParams)

        val frameParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ).apply { gravity = android.view.Gravity.CENTER }
        rootLayout.addView(centerLayout, frameParams)

        setContentView(rootLayout)
    }

    override fun onBackPressed() {
        // Block back — must tap Dismiss
    }
}