# ═══════════════════════════════════════════════════════════════════════════════
# Insight Editor — ProGuard / R8 rules  (v1.0.6)
#
# Philosophy:
#   Keep only what R8 cannot statically trace: JNI entry points, ServiceLoader
#   SPI implementations, reflection targets, and serialized data classes.
#   Everything else is left to R8 full-mode shrinking and optimization.
#
#   Rules are ordered from most-specific (app classes) to least-specific
#   (third-party libraries).  -dontwarn is used only for genuinely optional
#   compile-only dependencies, never to silence real linkage errors.
# ═══════════════════════════════════════════════════════════════════════════════


# ─── Crash-report readability ─────────────────────────────────────────────────
# Retain source file names and line numbers so stack traces in Firebase /
# Play Console are symbolicated correctly.  -renamesourcefileattribute replaces
# the obfuscated filename with the literal string "SourceFile" so the mapping
# file can reconstruct the original name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─── Reflection / serialization metadata ─────────────────────────────────────
# Required by Gson (Signature, EnclosingMethod), Room KSP (InnerClasses),
# and Kotlin metadata (RuntimeVisibleAnnotations).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
# Exceptions attribute is required for correct stack-trace reconstruction.
-keepattributes Exceptions


# ═══════════════════════════════════════════════════════════════════════════════
# APPLICATION ENTRY POINTS
# ═══════════════════════════════════════════════════════════════════════════════

# MainActivity — exported Activity, referenced by the OS via the manifest.
-keep class app.insighteditor.MainActivity { *; }

# ExportService — exported Service, referenced by the OS via the manifest.
-keep class app.insighteditor.export.ExportService { *; }

# ExportWorker — WorkManager instantiates this via reflection using the exact
# two-argument constructor (Context, WorkerParameters).  The Companion object
# holds KEY_* constants read back from WorkData by the UI layer.
-keep class app.insighteditor.export.ExportWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class app.insighteditor.export.ExportWorker$Companion { *; }
-keepclassmembers class app.insighteditor.export.ExportWorker {
    public static final app.insighteditor.export.ExportWorker$Companion Companion;
}
# OutputTarget is a private data class used internally by ExportWorker.
# R8 may inline it; keep it to preserve the ParcelFileDescriptor close path.
-keep class app.insighteditor.export.ExportWorker$OutputTarget { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# JNI / NDK NATIVE BRIDGE
# ═══════════════════════════════════════════════════════════════════════════════

# NativeEngine is the sole JNI boundary.  R8 cannot trace System.loadLibrary()
# at runtime, so the class name and every member must survive shrinking and
# obfuscation intact.  The C++ linker resolves entry points by the mangled name
# Java_app_insighteditor_native_NativeEngine_<methodName>; any rename breaks
# the dynamic linkage silently at runtime.
-keep class app.insighteditor.native.NativeEngine { *; }
-keepclasseswithmembernames class app.insighteditor.native.NativeEngine {
    native <methods>;
    private native <methods>;
}

# Safety net: any class anywhere in the app package that declares a native
# method must keep that method's exact name.
-keepclasseswithmembernames class app.insighteditor.** {
    native <methods>;
}


# ═══════════════════════════════════════════════════════════════════════════════
# DOMAIN MODELS — Gson serialization + Parcelable
# ═══════════════════════════════════════════════════════════════════════════════

# All data classes in the domain model layer are serialized to/from JSON by
# Gson.  Gson uses reflection to read field names; R8 must not rename them.
-keep class app.insighteditor.domain.model.** { *; }
-keepclassmembers class app.insighteditor.domain.model.** { *; }

# Enum constant names are serialized as strings by Gson and reconstructed via
# Enum.valueOf().  Obfuscating the names produces unresolvable JSON values.
-keepnames class app.insighteditor.domain.model.ExportCodec
-keepnames class app.insighteditor.domain.model.ExportFormat
-keepnames class app.insighteditor.domain.model.ExportResolution
-keepnames class app.insighteditor.domain.model.MediaType
-keepnames class app.insighteditor.domain.model.TrackType
-keepnames class app.insighteditor.domain.model.EffectType
-keepnames class app.insighteditor.domain.model.KeyframeProperty
-keepnames class app.insighteditor.domain.model.EasingType
-keepnames class app.insighteditor.domain.model.TextOverlayType
-keepnames class app.insighteditor.domain.model.WorkspaceTab
-keepnames class app.insighteditor.domain.model.EditTool


# ═══════════════════════════════════════════════════════════════════════════════
# DATA LAYER
# ═══════════════════════════════════════════════════════════════════════════════

# ProjectRepository registers a custom Gson TypeAdapter for Uri at runtime via
# GsonBuilder.registerTypeHierarchyAdapter().  The adapter class must survive.
-keep class app.insighteditor.data.repository.ProjectRepository { *; }
-keep class app.insighteditor.data.repository.UriTypeAdapter { *; }

# CacheManager generates LUT byte arrays loaded by NativeEngine.
-keep class app.insighteditor.data.repository.CacheManager { *; }

# PlaybackEngine holds an ExoPlayer instance; keep so R8 does not inline the
# class away when tracing from EditorViewModel.
-keep class app.insighteditor.data.media.PlaybackEngine { *; }

# ThumbnailCache uses MediaMetadataRetriever; keep to prevent field inlining.
-keep class app.insighteditor.data.media.ThumbnailCache { *; }

# MediaRepository uses MediaExtractor and MediaFormat via reflection-adjacent
# APIs; keep to prevent method inlining that would break the cursor loop.
-keep class app.insighteditor.data.media.MediaRepository { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# VIEW MODEL
# ═══════════════════════════════════════════════════════════════════════════════

# EditorViewModel is a @HiltViewModel — Hilt generates a factory class and
# injects it via the Hilt-extended ViewModelProvider.  Keep the ViewModel and
# its Hilt-generated factory so R8 does not remove the generated class.
-keep class app.insighteditor.viewmodel.EditorViewModel { *; }
-keep class app.insighteditor.viewmodel.EditorViewModel_HiltModules { *; }
-keep class app.insighteditor.viewmodel.EditorViewModel_HiltModules$* { *; }
# EditorUiState is a data class exposed as a StateFlow; its fields are read by
# Compose via generated component functions — keep all members.
-keep class app.insighteditor.viewmodel.EditorUiState { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# GL RENDERER
# ═══════════════════════════════════════════════════════════════════════════════

# GlRenderer loads GLSL shaders from assets at runtime and uses GL context
# setup that is reflection-adjacent.  Keep the class and all its members.
-keep class app.insighteditor.gl.GlRenderer { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# JETPACK MEDIA3 / EXOPLAYER  (version 1.6.1)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Media3 uses ServiceLoader SPI to discover renderers, extractors, decoders,
# and data sources at runtime.  R8 cannot trace ServiceLoader.load() calls.
# The blanket keep on androidx.media3.** is intentional and necessary — Media3
# ships its own consumer ProGuard rules but they are not always picked up
# correctly when R8 full-mode is enabled.
-keep class androidx.media3.** { *; }
-keepclassmembers class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Transformer / Effect pipeline — loaded via reflection inside the transformer
# graph builder, not covered by ServiceLoader rules.
-keep class androidx.media3.transformer.** { *; }
-keep class androidx.media3.effect.** { *; }

# Renderer / MediaSource / DataSource subclasses — instantiated by class name
# from MediaItem metadata or from the DefaultRenderersFactory registry.
-keep class * extends androidx.media3.exoplayer.Renderer { *; }
-keep class * extends androidx.media3.exoplayer.source.MediaSource { *; }
-keep class * extends androidx.media3.exoplayer.source.MediaSource$Factory { *; }
-keep class * extends androidx.media3.datasource.DataSource { *; }
-keep class * extends androidx.media3.datasource.DataSource$Factory { *; }

# MediaSession / MediaLibraryService — exported components.
-keep class * extends androidx.media3.session.MediaSessionService { *; }
-keep class * extends androidx.media3.session.MediaLibraryService { *; }

# Android MediaCodec / MediaMuxer / MediaExtractor — framework classes that
# survive shrinking automatically, but subclasses or wrappers must also be kept.
-keep class android.media.MediaExtractor { *; }
-keep class android.media.MediaFormat { *; }
-keep class android.media.MediaCodec { *; }
-keep class android.media.MediaCodecInfo { *; }
-keep class android.media.MediaCodecInfo$CodecCapabilities { *; }
-keep class android.media.MediaMuxer { *; }
-keep class android.media.MediaMetadataRetriever { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# JETPACK COMPOSE
# ═══════════════════════════════════════════════════════════════════════════════

# Compose compiler generates synthetic classes and uses reflection for
# remember/state restoration.  Keep the runtime and UI packages.
-keep class androidx.compose.runtime.** { *; }
-keep class androidx.compose.ui.** { *; }
-dontwarn androidx.compose.**

# Composable functions are annotated; keep the annotation so the compiler
# plugin can identify them at runtime.
-keepclassmembers class * {
    @androidx.compose.runtime.Composable <methods>;
}


# ═══════════════════════════════════════════════════════════════════════════════
# ANDROIDX WORKMANAGER
# ═══════════════════════════════════════════════════════════════════════════════

# WorkManager discovers Worker subclasses by class name from the WorkRequest
# input data.  All Worker constructors must survive.
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.CoroutineWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# AndroidX Startup — the WorkManagerInitializer class name is resolved by
# string from the manifest meta-data entry.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }
-keep class androidx.work.WorkManagerInitializer { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# ROOM DATABASE
# ═══════════════════════════════════════════════════════════════════════════════

# Room KSP generates implementation classes whose names are derived from the
# annotated class names.  Renaming the annotated classes breaks the generated
# code's class references at runtime.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keep @androidx.room.Database class * { *; }
-keepclassmembers @androidx.room.Entity class * { *; }
-keepclassmembers @androidx.room.Dao interface * { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# GSON
# ═══════════════════════════════════════════════════════════════════════════════

-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# KOTLIN
# ═══════════════════════════════════════════════════════════════════════════════

# kotlin.Metadata is read by Gson, Moshi, and other reflection-based libraries
# to discover Kotlin-specific type information.
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Coroutines — the main dispatcher factory and exception handler are loaded by
# class name via ServiceLoader.
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
# Volatile fields in coroutines internals must not be renamed (accessed via
# Unsafe.objectFieldOffset by name).
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Kotlin when-expression mapping classes generated by the compiler.
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# Kotlin companion objects accessed via reflection by some libraries.
-keepclassmembers class * {
    public static ** Companion;
}


# ═══════════════════════════════════════════════════════════════════════════════
# ANDROIDX LIBRARIES
# ═══════════════════════════════════════════════════════════════════════════════

# FileProvider — authority string is resolved by the OS from the manifest.
-keep class androidx.core.content.FileProvider { *; }

# DataStore Preferences — uses proto reflection internally.
-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# Navigation — back-stack state is restored via reflection.
-keep class androidx.navigation.** { *; }
-dontwarn androidx.navigation.**

# Lifecycle — ViewModel factory uses reflection to find the two-arg constructor.
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# SplashScreen — theme attribute lookup uses reflection.
-keep class androidx.core.splashscreen.** { *; }
-dontwarn androidx.core.splashscreen.**

# AppCompat — Theme.AppCompat.DayNight.NoActionBar referenced in styles.xml.
-keep class androidx.appcompat.** { *; }
-dontwarn androidx.appcompat.**

# Core notification / NotificationCompat.
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$Builder { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }
-keep class androidx.core.app.NotificationChannelCompat { *; }
-keep class androidx.core.app.NotificationChannelCompat$Builder { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# COIL  (version 3.x)
# ═══════════════════════════════════════════════════════════════════════════════

# Coil 3 uses ServiceLoader to discover ImageDecoders, Fetchers, and Keyers.
-keep class coil3.** { *; }
-dontwarn coil3.**


# ═══════════════════════════════════════════════════════════════════════════════
# ML KIT
# ═══════════════════════════════════════════════════════════════════════════════

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**


# ═══════════════════════════════════════════════════════════════════════════════
# ACCOMPANIST
# ═══════════════════════════════════════════════════════════════════════════════

-keep class com.google.accompanist.** { *; }
-dontwarn com.google.accompanist.**


# ═══════════════════════════════════════════════════════════════════════════════
# GENERAL ANDROID PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

# Enum values() and valueOf() are called reflectively by Gson and by Kotlin
# when-expressions compiled to switch tables.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable — the CREATOR field is accessed by the OS via reflection.
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable — writeObject/readObject are called reflectively.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# View constructors — inflated from XML by the OS via reflection.
-keepclasseswithmembers class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}


# ═══════════════════════════════════════════════════════════════════════════════
# NATIVE LIBRARY PACKAGING
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent R8 full-mode from eliminating the System.loadLibrary("insight_engine")
# call in the NativeEngine init block.  R8 full-mode can treat calls it
# considers side-effect-free as dead code; this rule marks the static
# initializer and constructor as observable entry points.
-keep class app.insighteditor.native.NativeEngine {
    <clinit>();
    <init>();
}


# ═══════════════════════════════════════════════════════════════════════════════
# LOG STRIPPING (release only)
# ═══════════════════════════════════════════════════════════════════════════════

# Remove all Android Log calls in release.  LOGE in native JNI is retained
# separately via the NDEBUG macro in CMakeLists.txt.
# -assumenosideeffects requires android.enableR8.fullMode=true (set in
# gradle.properties).
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int wtf(...);
}


# ═══════════════════════════════════════════════════════════════════════════════
# SUPPRESS WARNINGS FOR OPTIONAL / COMPILE-ONLY DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn javax.inject.**


# ═══════════════════════════════════════════════════════════════════════════════
# HILT (Dagger)
# ═══════════════════════════════════════════════════════════════════════════════

# Hilt generates _HiltComponents and _MembersInjector classes at compile time.
# R8 can trace them statically, but the generated class names must be kept so
# the component hierarchy resolves at runtime.
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep @dagger.hilt.android.lifecycle.HiltViewModel class * { *; }
-keep @dagger.hilt.android.AndroidEntryPoint class * { *; }
-keep @dagger.hilt.InstallIn class * { *; }

# Keep Hilt-generated component classes (suffix _HiltComponents).
-keep class **_HiltComponents* { *; }
-keep class **_GeneratedInjector { *; }

# AssistedInject factories used by HiltWorker.
-keep @dagger.assisted.AssistedInject class * { *; }
-keep @dagger.assisted.AssistedFactory interface * { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# FIREBASE CRASHLYTICS
# ═══════════════════════════════════════════════════════════════════════════════

# Crashlytics requires source file names and line numbers for symbolication.
# These are already kept by the -keepattributes block above.

# Keep the Crashlytics NDK bridge — required for C++ crash symbolication.
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-dontwarn com.google.firebase.analytics.**

# Firebase common
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services (transitive Firebase dependency)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**


# ═══════════════════════════════════════════════════════════════════════════════
# ROOM
# ═══════════════════════════════════════════════════════════════════════════════

# Room generates *_Impl classes at compile time. R8 can trace them, but the
# SPI registration via ServiceLoader must be kept.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keep @androidx.room.TypeConverters class * { *; }

# Room uses reflection to instantiate TypeConverters.
-keepclassmembers class app.insighteditor.data.db.converter.** { *; }


# ═══════════════════════════════════════════════════════════════════════════════
# MEDIA3 TRANSFORMER
# ═══════════════════════════════════════════════════════════════════════════════

-keep class androidx.media3.transformer.** { *; }
-dontwarn androidx.media3.transformer.**
-keep class androidx.media3.effect.** { *; }
-dontwarn androidx.media3.effect.**


# ═══════════════════════════════════════════════════════════════════════════════
# APP ENTRY POINTS (new classes added by this feature set)
# ═══════════════════════════════════════════════════════════════════════════════

-keep class app.insighteditor.InsightEditorApplication { *; }
# TransformerExportWorker uses @HiltWorker + @AssistedInject — Hilt generates
# a WorkerFactory.  Keep the worker and its generated factory.
-keep class app.insighteditor.export.TransformerExportWorker { *; }
-keep class app.insighteditor.export.TransformerExportWorker_AssistedFactory { *; }
-keep class app.insighteditor.export.TransformerExportWorker_HiltModule { *; }
-keep class app.insighteditor.shortcuts.ShortcutHelper { *; }
-keep class app.insighteditor.analytics.** { *; }
-keep class app.insighteditor.haptic.** { *; }
# Hilt-generated components and modules — R8 must not remove them.
-keep class app.insighteditor.di.** { *; }
-keep class dagger.hilt.** { *; }
-dontwarn dagger.hilt.**
-keep class * extends dagger.hilt.android.internal.managers.ActivityComponentManager { *; }
-keep @dagger.hilt.android.HiltAndroidApp class * { *; }
-keep @dagger.hilt.android.AndroidEntryPoint class * { *; }
-keep @dagger.hilt.android.lifecycle.HiltViewModel class * { *; }
