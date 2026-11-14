# libbox: Go calls these classes and methods by name through gomobile's JNI bridge.
-keep class go.** { *; }
-keep class io.nekohasekai.libbox.** { *; }
# The VPN service implements libbox interfaces that Go calls back, and the Rust
# bridge calls Native and its Host by name.
-keep class io.github.billblueinnit.boxpilot.core.** { *; }
-dontwarn io.nekohasekai.libbox.**
