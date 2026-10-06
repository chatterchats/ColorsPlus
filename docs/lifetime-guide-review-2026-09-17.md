# Picker lifetime / Lua guide review — v0.2.38

## Evidence and limits

Crash `UECC-Windows-FD7995BE4F83312F3D1B598D3235C132_0000` reports a
GameThread access violation reading `0x17`, with the first frames in UE4SS.
Logs end at 11:47:37 UTC while CP is active on Twi'lek Marking Color, following
RGB revision 2 and another palette resolution. The user recalls possibly moving
a slider. No exact native symbol/Lua line or reproducible trigger is available.
The last log line is not proof that palette discovery caused the crash.

This is a targeted hardening and compliance pass, not proof of crash resolution
or an exhaustive audit of every legacy experiment. No skin/horn write support,
new native hooks, game save, live recovery-file edits or installed Dev Panel
application changes are included.

## Corrections

- Picker view state now contains names and plain values only. Remove the
  long-lived widget wrappers and weak-key wrapper-to-name map; reacquire exact
  widget identities before use, without falling back to old wrappers.
- `set_rgb` and `show`, like `read`, require a freshly resolved, attached root.
  An already-destroyed root is treated as gone during cleanup; an actual removal
  error still retains its identity and blocks duplicate windows.
- A latched context-stop ends polling before further UI reads. Old polls and
  failed updates cannot reschedule or close a replacement picker after a
  synchronous native callback retires their session.
- RGB update validation returns its verified objects rather than doing another
  independent lookup before the setter. After SetColor, reacquire and verify
  the owned fragment and preview link before RefreshCustomization. Revalidate
  after refresh as before. Editor Apply/Restore also reacquire the source after
  SetColor. Recovery and later user edits retain their existing protections.
- Palette discovery still runs every required check, but prints only changed
  successful traces (failures remain visible). The first eight RGB revisions
  per preview log VALIDATE, SET COLOR, REFRESH and VERIFIED stages, allowing a
  missing RETURN marker to narrow a future crash. Unchanged polling is not traced.

## Guide checklist

Reviewed the complete local `Zero_Company_UE4SS_Lua_Guide.md` and the probe's
composition, runtime registry, picker, preview/editor ownership, palette,
logging, hook boundaries, diagnostics and local Dev Panel integration paths.

- Delayed UObject work uses owned game-thread handles; no worker-thread UObject
  polling or new construction observers were introduced. Runtime teardown
  retires callbacks, cancels handles, and retains failed cleanup for retry.
- Hook paths retain both IDs and teardown blocks replacement on unhook failure.
- Picker/tint/editor delayed state uses scalar identities/session tokens. The
  observational hook snapshots are a documented short-lived exception: they
  capture an object for a 1 ms job, validate it in the capture routine and cancel
  snapshots at screen boundaries. They are not permanent widget caches.
- Reflection/array unwrapping stays limited to recognized parameter wrappers
  and documented hook/array boundaries; arbitrary UObject `get` probing is absent.
- Startup hook discovery has finite retries; tracing windows are bounded.
  The optional Dev Panel client has its own persistent file-action polling
  lifetime, with replaced guarded handlers, not gameplay readiness polling.
- Dedicated logging includes runtime generation and flushes before shared
  output. Recovery remains journaled before mutation and native state is read
  back afterward. No new persistence format is needed for this patch.

The find-docs skill resolved `/ue4ss-re/re-ue4ss` via Context7 and checked the
official [delayed-action documentation](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/docs/lua-api/global-functions/delayedactions.md).
It confirms owned delayed game-thread actions and cancellation handles. That
documentation does not establish native UObject/Slate crash immunity.

Remaining limitations: IsValid and pcall cannot contain a native access
violation; names alone are not native serial-number identities; mocked tests
cannot simulate Unreal GC or Slate input. Full mod reload remains a separate
unresolved risk and is not part of this test. Broad property/call-by-call
instrumentation and deferred eye/legacy experiments were not redesigned.

## Focused retest

1. Fully restart into v0.2.38. Do not Reload All Mods or save for this check.
2. Open CP on Twi'lek Marking Color. Drag R/G/B for about 10 seconds, Cancel,
   reopen, and repeat several times. Confirm colors still update and restore.
3. Apply once, reopen and edit, then Cancel and Restore. Check both operations
   retain their previous meanings. Test leaving the color screen during preview.
4. Briefly repeat on the working tattoo slot. Skin and mixed-fragment horn/
   Togruta slots remain diagnostic-only; do not repeat their full surveys yet.
5. If it crashes, report the approximate action; the first eight changed RGB
   transactions have stage markers in `colors_plus_probe.log` and `UE4SS.log`.

Automated regressions cover detached/destroyed roots, newly acquired child
wrappers, failed-removal retries, re-entrant read/setter replacement, latched
context cancellation, post-setter preview replacement and quiet-but-live
palette validation, alongside the existing suite. In-game stability is pending.
