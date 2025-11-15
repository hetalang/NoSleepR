// src/nosleep_windows.c
// Windows backend for NoSleepR using Power Request API.

#ifdef _WIN32

#include <windows.h>
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

// Global state: power request handle and display flag.
// g_req_handle is NULL when no request is active.
static HANDLE g_req_handle  = NULL;
static BOOL   g_req_display = FALSE;

// .Call interface: NoSleepR_nosleep_on(keep_display = TRUE/FALSE)
SEXP NoSleepR_nosleep_on(SEXP keep_display_sexp) {
    if (!isLogical(keep_display_sexp) || LENGTH(keep_display_sexp) < 1) {
        Rf_error("NoSleepR_nosleep_on: 'keep_display' must be a logical scalar.");
    }

    int keep_display = LOGICAL(keep_display_sexp)[0];

    // Create power request handle if it does not exist.
    if (g_req_handle == NULL) {
        REASON_CONTEXT context;

        // Initialize context structure.
        ZeroMemory(&context, sizeof(REASON_CONTEXT));
        context.Version = POWER_REQUEST_CONTEXT_VERSION;            // usually 0
        context.Flags   = POWER_REQUEST_CONTEXT_SIMPLE_STRING;      // simple reason string
        context.Reason.SimpleReasonString = L"Set by user with NoSleepR";

        HANDLE h = PowerCreateRequest(&context);
        if (h == NULL) {
            Rf_error("NoSleepR_nosleep_on: PowerCreateRequest failed.");
        }

        g_req_handle = h;
    }

    // Activate system-required request.
    if (!PowerSetRequest(g_req_handle, PowerRequestSystemRequired)) {
        Rf_error("NoSleepR_nosleep_on: PowerSetRequest(SystemRequired) failed.");
    }

    // Optionally keep the display on.
    if (keep_display && !g_req_display) {
        if (!PowerSetRequest(g_req_handle, PowerRequestDisplayRequired)) {
            Rf_error("NoSleepR_nosleep_on: PowerSetRequest(DisplayRequired) failed.");
        }
        g_req_display = TRUE;
    }

    return R_NilValue;
}

// .Call interface: NoSleepR_nosleep_off()
SEXP NoSleepR_nosleep_off(void) {
    // If no handle, nothing to do.
    if (g_req_handle == NULL) {
        return R_NilValue;
    }

    HANDLE h = g_req_handle;

    // Clear system-required request (ignore return value).
    (void)PowerClearRequest(h, PowerRequestSystemRequired);

    // Clear display-required request if active (ignore return value).
    if (g_req_display) {
        (void)PowerClearRequest(h, PowerRequestDisplayRequired);
        g_req_display = FALSE;
    }

    // Close handle and reset global state.
    (void)CloseHandle(h);
    g_req_handle = NULL;

    return R_NilValue;
}

// Registration table for .Call

static const R_CallMethodDef CallEntries[] = {
    {"NoSleepR_nosleep_on",  (DL_FUNC) &NoSleepR_nosleep_on,  1},
    {"NoSleepR_nosleep_off", (DL_FUNC) &NoSleepR_nosleep_off, 0},
    {NULL, NULL, 0}
};

void R_init_NoSleepR(DllInfo *dll) {
    // Register native routines and disable dynamic symbol lookup.
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

#else  // !_WIN32

// Fallback stubs for non-Windows builds.

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP NoSleepR_nosleep_on(SEXP keep_display_sexp) {
    Rf_error("NoSleepR_nosleep_on: Windows backend is not available on this platform.");
}

SEXP NoSleepR_nosleep_off(void) {
    Rf_error("NoSleepR_nosleep_off: Windows backend is not available on this platform.");
}

void R_init_NoSleepR(DllInfo *dll) {
    // No registration needed on non-Windows platforms.
    (void)dll;
}

#endif
