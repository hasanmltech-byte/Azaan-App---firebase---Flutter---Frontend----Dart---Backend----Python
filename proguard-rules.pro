-dontwarn androidx.window.**
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**

# Keep all app classes
-keep class com.example.azaan_ramzan_timings.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# WorkManager — needed for AzanKeepAliveWorker
-keep class androidx.work.** { *; }
-keepnames class * extends androidx.work.Worker
-keepnames class * extends androidx.work.CoroutineWorker
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.CoroutineWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}