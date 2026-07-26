-keep class io.supabase.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn io.supabase.**
# Firebase Cloud Messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**