# libbox: Go calls these classes and methods by name through gomobile's JNI bridge.
-keep class go.** { *; }
-keep class io.nekohasekai.libbox.** { *; }
# The VPN service, tile and channel implement libbox interfaces that Go calls back.
-keep class io.github.billblueinnit.boxpilot.** { *; }
-dontwarn io.nekohasekai.libbox.**
