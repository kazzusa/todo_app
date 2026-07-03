# Keep generic signatures so Gson TypeToken works after R8 shrinking.
# flutter_local_notifications uses Gson to serialize scheduled notifications.
-keepattributes Signature
-keepattributes *Annotation*
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Keep home screen widget classes (referenced by AndroidManifest, must not be renamed)
-keep class com.personal.todo_app.TodoWidgetProvider { *; }
-keep class com.personal.todo_app.MainActivity { *; }
