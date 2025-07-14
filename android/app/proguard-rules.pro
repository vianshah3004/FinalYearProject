# Suppress warnings for ML Kit classes
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# Keep ML Kit text recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
# Keep Razorpay classes
-keep class com.razorpay.** { *; }
# Keep ProGuard annotations
-keep class proguard.annotation.** { *; }
# Keep Google Pay (NBUPaisa) classes for Razorpay integration
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** { *; }
# Suppress warnings for Google Pay classes
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**