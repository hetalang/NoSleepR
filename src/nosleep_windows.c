// src/nosleep_windows.c
// Windows backend for NoSleepR using Power Request API with per-request handles.

#ifdef _WIN32

#include <windows.h>
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Memory.h>  // for R_Calloc, R_Free

// Per-request state stored behind an external pointer.
// Each NoSleepRequest corresponds to a separate Power Request handle.
typedef struct {
    HANDLE handle;
    BOOL   display;
} NoSleepRequest;

// Finalizer: called when the R external pointer is garbage-collected.
// Ensures that the Power Request is cleared and handle is closed.
static void nosleep_finalizer(SEXP ext) {
    NoSleepRequest *req = (NoSleepRequest*) R_ExternalPtrAddr(ext);
    if (req == NULL) {
        return;
    }

    if (req->handle != NULL) {
        // Clear system-required request
        (void) PowerClearRequest(req->handle, PowerRequestSystemRequired);

        // Clear display-required request if it was set
        if (req->display) {
            (void) PowerClearRequest(req->handle, PowerRequestDisplayRequired);
        }

        (void) CloseHandle(req->handle);
        req->handle = NULL;
    }

    R_Free(req);
    R_ClearExternalPtr(ext);
}

// .Call interface:
//   SEXP NoSleepR_request_create(SEXP keep_display_sexp)
//
// On success:
//   - returns an external pointer to NoSleepRequest,
//   - with a registered finalizer that will clear/close the request.
//
// On failure (e.g. PowerCreateRequest / PowerSetRequest failed):
//   - returns R_NilValue (NULL in R).
//   - No warning here: R wrapper is responsible for emitting a warning.
SEXP NoSleepR_request_create(SEXP keep_display_sexp) {
    if (!isLogical(keep_display_sexp) || LENGTH(keep_display_sexp) < 1) {
        Rf_error("NoSleepR_request_create: 'keep_display' must be a logical scalar.");
    }

    int keep_display = LOGICAL(keep_display_sexp)[0];

    REASON_CONTEXT context;
    ZeroMemory(&context, sizeof(REASON_CONTEXT));
    context.Version = POWER_REQUEST_CONTEXT_VERSION;           // usually 0
    context.Flags   = POWER_REQUEST_CONTEXT_SIMPLE_STRING;     // simple reason string
    context.Reason.SimpleReasonString = L"Set by user with NoSleepR";

    HANDLE h = PowerCreateRequest(&context);
    if (h == NULL) {
        // Power Request API is unavailable or failed.
        // R wrapper should detect NULL and emit a warning.
        return R_NilValue;
    }

    // Activate system-required request.
    if (!PowerSetRequest(h, PowerRequestSystemRequired)) {
        (void) CloseHandle(h);
        return R_NilValue;
    }

    BOOL display = FALSE;
    if (keep_display) {
        if (!PowerSetRequest(h, PowerRequestDisplayRequired)) {
            (void) PowerClearRequest(h, PowerRequestSystemRequired);
            (void) CloseHandle(h);
            return R_NilValue;
        }
        display = TRUE;
    }

    NoSleepRequest *req = (NoSleepRequest*) R_Calloc(1, NoSleepRequest);
    req->handle  = h;
    req->display = display;

    SEXP ext = R_MakeExternalPtr((void*) req, R_NilValue, R_NilValue);
    R_RegisterCFinalizerEx(ext, nosleep_finalizer, TRUE);

    return ext;
}

// .Call interface:
//   SEXP NoSleepR_request_clear(SEXP ext)
//
// Clears and closes a specific NoSleepRequest associated with the given
// external pointer. Safe to call multiple times; subsequent calls become no-ops.
SEXP NoSleepR_request_clear(SEXP ext) {
    NoSleepRequest *req = (NoSleepRequest*) R_ExternalPtrAddr(ext);
    if (req == NULL) {
        return R_NilValue;
    }

    if (req->handle != NULL) {
        (void) PowerClearRequest(req->handle, PowerRequestSystemRequired);

        if (req->display) {
            (void) PowerClearRequest(req->handle, PowerRequestDisplayRequired);
        }

        (void) CloseHandle(req->handle);
        req->handle = NULL;
    }

    R_Free(req);
    R_ClearExternalPtr(ext);

    return R_NilValue;
}

// Registration table for .Call

static const R_CallMethodDef CallEntries[] = {
    {"NoSleepR_request_create", (DL_FUNC) &NoSleepR_request_create, 1},
    {"NoSleepR_request_clear",  (DL_FUNC) &NoSleepR_request_clear,  1},
    {NULL, NULL, 0}
};

void R_init_NoSleepR(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

#else  // !_WIN32

// Fallback stubs for non-Windows builds.

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP NoSleepR_request_create(SEXP keep_display_sexp) {
    (void) keep_display_sexp;
    Rf_error("NoSleepR_request_create: Windows backend is not available on this platform.");
}

SEXP NoSleepR_request_clear(SEXP ext) {
    (void) ext;
    Rf_error("NoSleepR_request_clear: Windows backend is not available on this platform.");
}

// Even on non-Windows, it is good practice to register native routines
// and disable dynamic symbol lookup to satisfy R CMD check.
static const R_CallMethodDef CallEntries[] = {
    { "NoSleepR_request_create", (DL_FUNC) &NoSleepR_request_create, 1 },
    { "NoSleepR_request_clear",  (DL_FUNC) &NoSleepR_request_clear,  1 },
    { NULL, NULL, 0 }
};

void R_init_NoSleepR(DllInfo *dll) {
    // No registration for non-Windows; this file is not used there.
    // (void) dll;

    // register anyway to avoid R CMD check notes
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

#endif
