# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep your application classes that will be accessed from native code
-keep class com.teampisir.pisir.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep custom application class
-keep public class * extends android.app.Application

# Keep custom views
-keep public class * extends android.view.View

# Keep custom activities
-keep public class * extends android.app.Activity

# Keep custom services
-keep public class * extends android.app.Service

# Keep custom receivers
-keep public class * extends android.content.BroadcastReceiver

# Keep custom providers
-keep public class * extends android.content.ContentProvider

# Keep custom back stacks
-keep public class * extends android.app.backup.BackupAgentHelper

# Keep custom interfaces
-keep public interface * extends android.os.IInterface

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep custom annotations
-keep public class * extends java.lang.annotation.Annotation

# Keep custom enums
-keep public enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep custom generic signatures
-keepattributes Signature

# Keep custom source file names
-keepattributes SourceFile,LineNumberTable

# Keep custom exceptions
-keepattributes Exceptions

# Keep custom inner classes
-keepattributes InnerClasses

# Keep custom annotations
-keepattributes *Annotation*

# Keep custom bridge methods
-keepattributes BridgeMethods

# Keep custom synthetic methods
-keepattributes Synthetic

# Keep custom deprecation
-keepattributes Deprecated

# Keep custom JavaScript interface
-keepattributes JavascriptInterface

# Keep custom JavaScript interface methods
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep custom JavaScript interface fields
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <fields>;
}

# Keep custom JavaScript interface constructors
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <init>(...);
}

# Keep custom JavaScript interface classes
-keepclassmembers class * implements android.webkit.JavascriptInterface {
    <init>(...);
}

# Keep custom JavaScript interface interfaces
-keepclassmembers interface * extends android.webkit.JavascriptInterface {
    <init>(...);
}

# Keep custom JavaScript interface annotations
-keepclassmembers @interface * extends android.webkit.JavascriptInterface {
    <init>(...);
}

# Keep custom JavaScript interface enums
-keepclassmembers enum * implements android.webkit.JavascriptInterface {
    <init>(...);
}

# Keep custom JavaScript interface exceptions
-keepclassmembers class * extends java.lang.Exception implements android.webkit.JavascriptInterface {
    <init>(...);
}

# Keep custom JavaScript interface generic signatures
-keepattributes Signature

# Keep custom JavaScript interface source file names
-keepattributes SourceFile,LineNumberTable

# Keep custom JavaScript interface exceptions
-keepattributes Exceptions

# Keep custom JavaScript interface inner classes
-keepattributes InnerClasses

# Keep custom JavaScript interface annotations
-keepattributes *Annotation*

# Keep custom JavaScript interface bridge methods
-keepattributes BridgeMethods

# Keep custom JavaScript interface synthetic methods
-keepattributes Synthetic

# Keep custom JavaScript interface deprecation
-keepattributes Deprecated 