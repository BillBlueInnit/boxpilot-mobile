package io.github.billblueinnit.boxpilot.core

/** The Rust bridge (`rust/src/android.rs`): the engine behind one JSON entry point. */
object Native {
    /** What the engine asks of the app. Called from engine threads. */
    interface Host {
        /** Starts or reloads libbox; blocks until done. Empty string, or the error. */
        fun startCore(config: String): String

        fun stopCore()

        /** An engine event as JSON. */
        fun onEvent(json: String)
    }

    init {
        System.loadLibrary("boxpilot_bridge")
    }

    /** `"true"`: the engine was already running; `"false"`: created; else `"error: …"`. */
    external fun init(root: String, coreVersion: String, vpnReady: Boolean, host: Host): String

    /** Calls an engine method. Returns `{"ok": …}` or `{"error": "…"}`. Blocks. */
    external fun invoke(method: String, args: String): String

    external fun isRunning(): Boolean
}
