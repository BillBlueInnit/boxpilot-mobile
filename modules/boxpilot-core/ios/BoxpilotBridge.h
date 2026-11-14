// The Rust bridge (rust/src/ffi.rs): the engine behind one JSON entry point.
// Strings are NUL-terminated UTF-8.

#ifndef BOXPILOT_BRIDGE_H
#define BOXPILOT_BRIDGE_H

#include <stdbool.h>

// Starts (or reloads) the core; blocks until done. Returns NULL on success,
// else an error allocated with strdup (the bridge frees it).
typedef char *(*boxpilot_start_fn)(const char *config);
typedef void (*boxpilot_stop_fn)(void);
// An engine event as JSON; copy it before returning.
typedef void (*boxpilot_event_fn)(const char *event);

// Creates the engine (once). "true": it was already running; "false": created;
// else "error: ...". Free the answer with boxpilot_free.
char *boxpilot_init(const char *root, const char *core_version, bool vpn_ready,
                    boxpilot_start_fn start, boxpilot_stop_fn stop, boxpilot_event_fn event);

// Calls an engine method with JSON arguments. Returns {"ok": ...} or
// {"error": "..."}; free it with boxpilot_free. Blocks.
char *boxpilot_invoke(const char *method, const char *args);

void boxpilot_free(char *p);

#endif
