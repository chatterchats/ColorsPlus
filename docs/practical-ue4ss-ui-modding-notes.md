# Star Wars: Zero Company — Practical UE4SS UI Modding Notes

## Purpose

This guide summarizes UI work from **Character Share**, which adds controls and dialogs to Zero Company’s Character Databank, and **Colors+**, which adds live color editing to character customization.

Updated September 18, 2026. The original Character Share observations are retained; Colors+ adds lessons about preview ownership, object replacement, delayed work, and persistence.

Evidence labels used in the additions:

* **Verified behavior** — observed in the stated in-game test, not a guarantee for every screen or game build.
* **Project-specific workaround** — successful within the recorded context; validate before adopting elsewhere.
* **Unresolved experiment** — not a working recipe or proof of a proposed cause.

It is not intended to be a complete Unreal Engine UI reference. Instead, it documents techniques that actually worked in Zero Company, approaches that caused instability, and a few patterns that should be useful to other mod authors adding or modifying game UI.

The biggest overall lesson was simple:

> **Work with the game’s existing UI instead of trying to replace it.**

Zero Company uses Unreal’s UMG and CommonUI systems heavily. Those systems maintain their own focus, navigation, activation, selection, and screen-stack state. A UI modification can look perfectly correct while quietly disrupting one of those systems and causing bugs later.

Character Share became much more reliable once it stopped treating the UI as a static widget tree and started treating it as a **live system with a lifecycle**.

---

# 1. Understanding the UI layers

There are two important pieces involved in most of the UI we touched.

**UMG** is Unreal’s widget system. Things such as horizontal boxes, vertical boxes, spacers, text blocks, buttons, overlays, and size boxes are UMG widgets.

**CommonUI** sits on top of that and handles things such as screen activation, navigation, controller/keyboard focus, bound action buttons, and popup stacks.

That distinction matters because modifying a UMG widget can have consequences in CommonUI.

For example, removing and recreating children in a panel may appear harmless from a layout perspective, but CommonUI may already have references to the original widgets for selection or focus.

That was the source of several of our early problems.

---

# 2. Prefer native game widgets over custom-looking replacements

The most successful approach was to **clone or create the same widget classes the game already uses**.

For Character Share:

* `IMPORT` uses the same widget class as the Databank's native **Create New** button:
  `WBP_CharacterBankCreateNewBtn_C`
* `SHARE` uses the same general action-button class as Edit/Delete/Activate:
  `WBP_BoundActionButton_C`
* Popup actions use:
  `WBP_CharacterDataBank_TopNavButton_C`
* Dialogs use the game's:
  `WBP_GenericPopupMessage_Small_C`

This has several advantages.

The game already supplies fonts, materials, animations, input behavior, button states, controller navigation, scaling, and visual styling. Reusing those means the new control naturally looks like part of the game instead of something drawn over the top of it.

It also reduces the number of assumptions your mod has to make.

A hand-built button might look correct at 1920×1080 with a mouse but fail with controller navigation, ultrawide layouts, UI scaling, or some CommonUI state.

A cloned native button inherits most of that behavior automatically.

---

# 3. Do not rebuild native UI containers unless absolutely necessary

This was probably the most important lesson from the entire project.

Early Character Share versions experimented with things such as:

```text
ClearChildren()
re-add original widgets
insert our widget
```

or attempting operations such as:

```text
InsertChildAt()
ReplaceChildAt()
```

These approaches caused two separate classes of problems.

First, some UMG panel functions exposed through UE4SS did not behave like normal callable Lua methods. `InsertChildAt`, for example, surfaced as a `TrivialObject` in our environment rather than something reliably callable.

Second, and more importantly, rebuilding native containers disrupted game state.

The Character Databank could initially appear correct, but character selection would not work until leaving the screen and coming back. The visual tree existed, but the game had initialized its selection/navigation logic against a different structure.

The reliable strategy became:

> **Leave the game's original children alone. Append your own widgets and adjust only your own layout.**

For Character Share, that meant using the reliable `AddChild` path and then positioning the appended widget visually where we wanted it.

That sounds slightly inelegant compared with inserting at an exact index, but it proved dramatically safer.

---

# 4. Visual placement can be safer than structural placement

A useful workaround emerged from the lack of reliable `InsertChildAt`.

Rather than rearranging the game's children, Character Share appends its widget and applies a render translation so it appears in the desired position.

For the Create New / Import area, we measured the native layout and split the available width:

```text
original row width: 864
gap:                8
target width:       428 each
```

The mod then placed the new Import button visually alongside Create New without reconstructing the native list panel.

The important distinction is:

**Structural change**

```text
Game child 1
Game child 2
Game child 3

becomes

Game child 1
Our child
Game child 2
Game child 3
```

versus:

**Non-destructive visual change**

```text
Game child 1
Game child 2
Game child 3
Our child
```

with our child translated to where it should appear.

CommonUI still sees the native structure it initialized, while the player sees the desired layout.

That was a good tradeoff.

---

# 5. UI creation must respect screen initialization

One of the harder bugs was the Databank working only **after leaving the screen and returning**.

The first time into the screen, selection would be broken. On the second visit, it worked.

This turned out to be a timing/lifecycle problem.

The Databank screen existed before it was necessarily safe to modify. A widget being discoverable does not mean CommonUI has finished initializing it.

The eventual solution was a **stable re-observation** approach.

When the player clicks the Strategy submenu item:

1. Character Share starts a short bounded check for the Databank.
2. It finds a candidate screen.
3. It does **not** modify it immediately.
4. It waits briefly and finds the same live screen again.
5. Only after seeing the same runtime object twice does integration begin.

In the logs this looked roughly like:

```text
Databank entry probe observed live candidate on attempt 1;
waiting for one stable re-observation.

Databank entry probe stabilized on attempt 2;
beginning UI integration.
```

That tiny delay eliminated a surprising number of problems in Character Share. **Project-specific workaround:** observing the same screen twice is a useful entry heuristic, not proof that every dependent object is ready.

Colors+ showed why the distinction matters: the screen may remain alive while its selected slot, customization fragments, preview actor, or material instances change. Deferred work must resolve and validate its actual target when it runs, not rely solely on the screen observed when it was queued.

The broader lesson is:

> **Object exists** and **object is ready** are not the same thing.

---

# 6. Be careful querying transient CommonUI state

At one point we attempted to use activation checks such as `IsActivated()` while determining whether a Databank master was usable.

That caused intermittent crashes.

The safer approach was to avoid poking transient CommonUI state during that narrow initialization window and instead verify simpler conditions:

* Is the object valid?
* Is it attached?
* Is it visible?
* Is it the same runtime identity we observed previously?

The stable-object check was sufficient without interrogating every bit of CommonUI state.

When working through UE4SS, fewer engine calls during unstable transitions is generally better.

---

# 7. Runtime identity matters

Zero Company often keeps UI objects alive and reuses them.

The Character Databank is a good example.

Leaving the screen does not necessarily mean its widget object is destroyed. When returning, the game may reuse the same `WBP_CharacterBank_Master_C`.

If a mod blindly installs its widgets every time the screen appears, that produces duplicate controls or stale callback mappings.

Character Share therefore tracks the actual runtime object identity of the Databank master.

When it encounters the same master again:

```text
Character Databank reusable runtime master detected;
adopting existing Character Share controls.
```

It reuses the already-installed controls.

If an entirely new master appears, stale mappings are discarded and integration starts fresh.

This is a useful general pattern:

```text
screen appears
    ↓
same runtime object?
    ├─ yes → reuse/adopt
    └─ no  → reset state and install
```

Do not assume that navigation means destruction/recreation. Conversely, a surviving screen does not imply that all objects beneath it survived.

For deferred Colors+ operations, retain scalar identity/context records and reacquire live objects before use. Validate their current owner, slot, and expected role. A runtime name or validity check alone is not proof that an object still represents the intended edit.

---

# 8. Treat both pages of a multi-page screen independently

The Character Databank contains separate character-list pages for:

```text
OtherCharacterList
AstromechCharacterList
```

They look like tabs of one screen to the player, but internally they are separate live widget trees.

Installing a button into only the currently visible page is therefore not enough.

Character Share integrates into both pages when entering the Databank.

That avoided having button availability depend on which tab was active during setup.

The broader lesson:

> Tabs, switchers, and pages may each contain their own instances of controls that appear conceptually shared.

Inspect the actual tree rather than assuming a visual element exists only once.

---

# 9. Cloning a widget does not mean cloning its current visual state

This created the long-running Share-button orientation problem.

We created Share from the same class used by the native Edit button:

```text
WBP_BoundActionButton_C
```

But the clone did not inherit Edit's current configured appearance.

Native Edit was effectively:

```text
orientation = Right
size        = Default
type        = Default
```

while the new clone came up using its class defaults:

```text
orientation = Left
```

So the Share button looked backwards.

This is an important Unreal concept:

> Creating another object of the same class gives you the class defaults, not necessarily the live instance's configured state.

---

# 10. Prefer public style properties/functions over manipulating internal child widgets

We initially tried to force the Share visual by reaching inside the Bound Action Button's widget switcher.

The class contains things such as:

```text
WBP_Default_Right
WBP_Default_Left
ButtonSwitcher
SelectedButton
ButtonOrientation
ButtonSize
ButtonType
```

Manipulating the switcher and selected child directly was fragile and contributed to crashes.

The stable solution was much simpler:

```lua
button.ButtonOrientation = 1
button.ButtonSize = 0
button.ButtonType = 0
button:ApplyStyle()
```

The game itself then selected the appropriate visual.

This is a very useful rule:

> If a widget exposes a property plus an `ApplyStyle`, `UpdateStyle`, `Refresh`, or similar function, prefer that over manually changing its internal widget tree.

Let the Blueprint perform its own state transition.

---

# 11. Copy spacing from the UI rather than guessing

Once Share had the correct orientation, it was still visually too close to Activate.

The native action row contains `Spacer` widgets between its controls.

Instead of guessing at margins, Character Share finds the native spacer following Edit and clones its dimensions.

In the current game layout that spacer measured:

```text
24 px
```

A new `/Script/UMG.Spacer` is created and assigned the same size/layout values.

This gives us:

```text
EDIT   DELETE   ACTIVATE   SHARE
                       ↑
                same native rhythm
```

rather than a hand-tuned approximation.

That pattern generalizes nicely:

> When adding to an existing row, inspect and reuse the game's spacing rather than inventing your own.

It is more likely to remain visually consistent across resolutions and future changes.

---

# 12. CommonUI button callbacks can still be running after your hook fires

This produced one of the nastier late-development crashes.

Character Share hooks:

```text
CommonButtonBase:HandleButtonClicked
```

When Share was clicked, the mod immediately:

1. encoded the character;
2. created a popup;
3. pushed the popup into CommonUI.

The entire export completed successfully according to the log.

Then the game crashed.

The important realization was that **our hook firing did not mean the native button click had finished**.

`WBP_BoundActionButton` still had additional native/CommonUI work to perform after `HandleButtonClicked` returned.

By opening another CommonUI layer inside that callback, we were changing focus and screen-stack state while the original button was still processing itself.

The fix was to defer our action very slightly:

```text
button click
    ↓
record intended Share action
    ↓
return to native CommonUI
    ↓
native click finishes
    ↓
next game-thread tick
    ↓
perform export/open popup
```

That resolved the reproduced Share crash. It does not establish that all click-related crashes share that cause.

---

# 13. Apply the same rule consistently

Much later, during repeated error-code testing, Import produced a very similar crash.

The log stopped immediately after:

```text
Databank button clicked: IMPORT
IMPORT SESSION started
```

before the import popup was created.

We applied the same pattern:

> Do not open another CommonUI screen directly from inside a native button's click processing.

Import now also queues its action and opens the dialog on the following game-thread tick.

This gave us one of the most reusable patterns from the project:

```text
Native button event
      ↓
Mod sees event
      ↓
Queue work
      ↓
Native event returns
      ↓
Owned, cancellable game-thread delay
      ↓
Create/change CommonUI screens
```

For anything that opens or closes UI, this is safer than doing everything synchronously from a click hook.

**Important distinction:** running on the game thread and running after the native event has unwound are separate requirements. Do not assume that a game-thread dispatch primitive necessarily supplies the required deferral. Colors+ uses tracked delayed actions, then revalidates the current context inside the callback. A fixed delay is not a substitute for checking popup retirement or target readiness.

---

# 14. Native popup dialogs are worth reusing

Character Share originally needed several dialog types:

```text
Share code display
Import text entry
Duplicate choice
Rename text entry
Success/error notice
```

Instead of creating a new custom popup framework, we reuse:

```text
WBP_GenericPopupMessage_Small_C
```

This gives us a popup already integrated into:

* the CommonUI stack;
* game focus;
* controller navigation;
* game visual style;
* input blocking;
* screen scaling.

Character Share then adjusts the title/body/input field and replaces the actions with suitable native-style buttons.

This was much more reliable than building an independent overlay.

---

# 15. Reused popup instances must be reset

An interesting behavior of Zero Company's popup system is that the same popup object can be reused for several consecutive dialogs.

For example:

```text
Import
    ↓
Duplicate detected
    ↓
Rename
    ↓
Success
```

may all involve the same underlying popup widget being configured repeatedly.

Any UI elements injected by the mod therefore need to be removed/reset before configuring the next dialog.

Character Share explicitly clears its injected slots before each popup setup.

Otherwise stale buttons or state from the previous dialog can leak into the next one.

---

# 16. Let the native popup retire before acting on its result

A similar CommonUI timing rule applies when closing a dialog.

When a popup action is clicked, immediately creating the next popup can collide with the old one still being on the CommonUI stack.

The robust sequence became:

```text
User chooses RENAME
        ↓
Native popup begins closing
        ↓
Character Share records "duplicate_rename"
        ↓
Wait until the current dialog has retired
        ↓
Dispatch duplicate_rename
        ↓
Open Rename dialog
```

Logs during normal operation therefore contain messages such as:

```text
Popup TopNav click
Popup TopNav dispatch after native close
```

or, for native dialog results:

```text
Native dialog result captured
awaiting native stack retirement

Native dialog retired from CommonUI

Native dialog dispatch after retirement
```

This prevented popup chains from fighting the CommonUI layer stack.

---

# 17. A plain TopNav button turned out to be a very safe action control

During debugging we tried several button types.

`WBP_CharacterDataBank_TopNavButton_C` proved particularly reliable for dialog actions.

It was successfully used for:

```text
IMPORT
CANCEL
OVERWRITE
RENAME
OK
CLOSE
```

Because it already belongs to the Character Databank UI family, it also visually fits the surrounding interface.

One potentially useful pattern for future mods is therefore:

> For a modal action where you do not need the complexity of `WBP_BoundActionButton`, a native TopNav-style button may be the safer choice.

The Bound Action Button remains useful when matching a specific existing action row, but it carries more internal CommonUI behavior.

---

# 18. Keep callback routing separate from the widget itself

Character Share does not put a unique UE4SS hook on every individual button.

Instead, it registers a general CommonUI button click hook and maintains a mapping:

```text
runtime widget identity
        ↓
Character Share action
```

Conceptually:

```text
SomeWidget123 → databank_import
SomeWidget456 → databank_share
SomeWidget789 → duplicate_rename
```

The hook sees a click, determines whether that widget belongs to Character Share, and dispatches the corresponding action.

This was easier to manage than installing large numbers of separate native hooks.

It also made stale-widget cleanup important, which is why runtime screen generations and identity tracking became useful.

---

# 19. Assume widget internals can be missing

Another recurring lesson was not to assume that every child shown in a dump will exist in every instance.

At different points we encountered things such as:

```text
SizeBox_0 not present
expected helper/widget not available
different child counts
```

UI code should therefore be defensive.

Instead of:

```lua
widget.SizeBox_0:SetWidthOverride(...)
```

the safer pattern is conceptually:

```text
find expected child
    ↓
exists?
    ├─ yes → configure it
    └─ no  → skip/fallback/log
```

A missing decorative child should not prevent the entire mod UI from loading.

---

# 20. Object dumps are extremely useful, but live behavior matters more

UE4SS ObjectDump information was invaluable for learning widget structure.

It revealed fields and functions such as:

```text
ButtonOrientation
ButtonSize
ButtonType
ButtonSwitcher
SelectedButton
ApplyStyle
```

and helped identify where native spacers and action buttons lived.

But a dump tells you what exists, not necessarily **when it is safe to touch it**.

Several things that looked reasonable from static inspection caused runtime instability because the widget was in the middle of a CommonUI transition.

So a good workflow became:

```text
ObjectDump
    ↓
Understand structure
    ↓
Minimal runtime probe
    ↓
Log values without changing anything
    ↓
Only then modify
```

The Share orientation fix is a good example.

We first added a diagnostic build that logged the live native Edit/Delete/Activate state and the freshly-created Share state.

That showed clearly:

```text
native Edit:
orientation = Right

fresh Share:
orientation = Left
```

Once we knew the actual difference, the fix was tiny.

---

# 21. Diagnostic builds are better than guessing

A number of bugs were solved fastest by creating deliberately small "probe" builds.

Instead of changing five things and asking whether the UI looked better, we would log:

* class name;
* object identity;
* parent;
* child count;
* active switcher state;
* button orientation;
* measured width;
* selected widget;
* whether the page had been observed previously.

This produced actionable evidence.

For UI modding especially, a useful diagnostic log entry is more valuable than pages of speculative code changes.

The general pattern was:

```text
observe
→ measure
→ reproduce
→ change one thing
→ validate
```

rather than continually rebuilding the UI until something happened to work.

---

# 22. Log lifecycle boundaries, not just errors

The most useful Character Share logs were usually not exception messages.

They were breadcrumbs such as:

```text
Databank candidate observed
Databank stabilized
UI integration started
Share installed
Share clicked
Share queued
Share dispatched
Popup opened
Popup click
Popup retired
Next action dispatched
```

When a native crash occurs, Lua does not necessarily get a chance to print an error.

The **last successful breadcrumb** narrows the interval where execution stopped; it does not by itself prove the cause. A crash can occur after a call returns or during native work that the call triggered.

These breadcrumbs helped us investigate distinctions between:

```text
codec failure
```

from:

```text
popup creation failure
```

from:

```text
native button still unwinding
```

from:

```text
screen entry lifecycle crash
```

For UE4SS UI mods, detailed lifecycle logging during development is extremely worthwhile.

Colors+ extended this with paired `BEGIN` and `RETURN` records around individual native calls, correlated by runtime generation, trace window, and call ID. A missing return identifies a suspect boundary, not conclusive causation. Record Lua errors separately, and bound tracing by both duration and call count to avoid flooding logs during slider updates.

---

# 23. Avoid modifying native controls just to make your new control match

One early visual approach restyled the existing Edit/Delete/Activate buttons so they matched Share.

Technically that solved one appearance mismatch.

It was also the wrong direction.

A mod adding one button should not need to alter three unrelated native buttons.

The better solution was:

```text
preserve native UI
        +
make new control match native UI
```

This reduced the amount of game state we touched and made regressions much easier to reason about.

That principle should apply broadly:

> Modify only what your mod owns unless changing the native control is actually the feature.

---

# 24. A useful hierarchy for UI modifications

After all of the iterations, I'd roughly rank Zero Company UI modification techniques from safest to riskiest like this:

| Approach                                                             | Relative risk |
| -------------------------------------------------------------------- | ------------- |
| Read properties on freshly resolved, validated widgets in a stable context | Lower, not risk-free |
| Create a native-class widget owned by the current screen             | Low           |
| Append your widget to a native panel                                 | Low           |
| Change properties on your own widget                                 | Low           |
| Apply render translation to your widget                              | Low           |
| Call the widget's own style/update functions                         | Low–moderate  |
| Change properties on native widgets                                  | Moderate      |
| Manipulate native WidgetSwitcher internals                           | Higher        |
| Reorder/remove existing native children                              | High          |
| Clear and reconstruct native CommonUI panels                         | Very high     |
| Modify CommonUI layers while a click/close event is still processing | Very high     |

That is not an Unreal-wide law; it describes relative risk observed during Character Share development, qualified by the later Colors+ work. Every row assumes appropriate thread, lifecycle, and ownership checks.

Even reads can touch stale native objects. `pcall` catches Lua errors; it does **not** protect against native access violations. Reacquire and validate targets, minimize calls during transitions, and do not treat successful earlier access as a lifetime guarantee.

---

# 25. Recommended pattern for adding a button to an existing Zero Company screen

If starting another UI mod tomorrow, I would use approximately this process:

```text
1. Find the screen/widget class with ObjectDump or runtime logging.

2. Enter the screen normally and record its actual runtime tree.

3. Identify the native widget you want your control to resemble.

4. Wait until the screen has stabilized before modifying it.

5. Create a widget using the game's native class where possible.

6. Add only your own widget; avoid removing/reordering game children.

7. Copy useful layout/style information from the nearby native controls.

8. Use public properties + ApplyStyle/Update functions rather than
   manipulating internal switchers.

9. Route button clicks through a small action mapping.

10. If the action opens/closes CommonUI, defer execution until the
    current native click has unwound.

11. If chaining dialogs, wait for the previous dialog to retire before
    pushing another.

12. Track runtime screen identity so reusable screens do not receive
    duplicate controls.

13. Log every important lifecycle boundary while developing.

14. Own and cancel delayed work; retire callbacks and mappings when
    their runtime generation or editing context ends.

15. Test hover, selection, cancellation, timeout, screen round trips,
    and object replacement independently.

16. For editing tools, test Apply, native Save/reopen, and full-restart
    persistence separately. They are not equivalent.

17. Once stable, remove or disable probe/debug instrumentation that is
    no longer useful. Keep useful lifecycle and failure records.
```

That pattern accounts for nearly every major failure we encountered.

---

# 26. What Character Share specifically taught us

The UI work started out looking fairly straightforward:

> Add an Import button, add a Share button, and show a few dialogs.

The difficult part was not drawing the controls.

It was learning how the game expects its interface to behave.

The problems we encountered included:

* character selection failing only on first entry;
* controls appearing correctly but interfering with CommonUI state;
* unreliable `InsertChildAt`;
* duplicated controls after screen re-entry;
* a cloned button having the opposite orientation from its native neighbor;
* spacing that looked subtly wrong despite using the same widget class;
* crashes caused by inspecting transient button/screen state;
* crashes occurring *after* a Share export had completely succeeded;
* crashes while repeatedly opening Import;
* popup actions firing before the previous popup had left the stack.

Almost none of those were traditional Lua errors.

They were **UI lifecycle errors**.

The eventual implementation became reliable because it consistently follows four rules:

> **Preserve native widgets.**
> **Wait for UI state to stabilize.**
> **Let native events finish before changing CommonUI state.**
> **Use the game's own widget classes and styling logic whenever possible.**

Those are probably the most valuable lessons to carry into future Zero Company UI mods.

---

# 27. Areas we still have not explored deeply

There are parts of Zero Company's UI system that Character Share did not need to investigate enough to document confidently.

For example, we have not done extensive work with:

* creating entirely new CommonActivatableWidget screens;
* adding permanent tabs to major game interfaces;
* drag-and-drop;
* ListView entry creation and recycling;
* custom tooltip systems;
* gamepad navigation graphs for entirely custom screens;
* Slate-level rendering;
* HUD/combat UI modification;
* responsive custom layouts across every aspect ratio.

So I would keep this guide explicitly labeled as a **starting knowledge base**, not a complete UI SDK.

But for the very common case of:

> "I want to add controls and dialogs to an existing Zero Company menu"

we now have a pretty solid foundation.

---

# 28. Give each tool its own lifecycle

**Verified behavior in Colors+ testing:** the Color Picker closes when its customization context ends, while the SWZC Dev Panel can remain open across the Customization–Databank transition.

These windows have different responsibilities.

* The picker owns a preview for a particular selection. A slot/page change can invalidate that preview.
* The Dev Panel is a general-purpose launcher. Its continued visibility does not authorize an action against the previous screen.

Validate each Dev Panel action against the current context at dispatch time. Keeping the launcher open is useful for testing transitions; closing every mod window on every transition is not a universal safety requirement.

Similarly, a native swatch hover, a committed swatch selection, a return to the radial selector, and departure from the creator are different events. Decide explicitly which ends a draft preview, which replaces an applied edit, and which merely changes what is displayed.

---

# 29. Own delayed work, hooks, and runtime generations

**Implemented pattern in Colors+:** keep a registry of named delayed actions and hook registrations. Replacement work cancels the previous action for that purpose. Each callback checks that its runtime is still active before doing anything.

Useful ownership information includes:

* runtime generation;
* editing session or preview identity;
* action key and cancellation handle;
* registered hook identifiers;
* the source owner and slot the operation expects.

On retirement, disable old callback routing, cancel owned work, and unregister owned hooks. Cleanup failures should remain visible and tracked rather than being logged as successful teardown.

Do not retain a native object wrapper merely because a timer will need it later. Retain sufficient scalar identity/context information to reacquire and validate the target when the timer runs.

**Unresolved reload limitation:** Reload All Mods is not equivalent to closing and reopening a window. Testing with both DP and CP open produced a hang/crash even though other tested combinations worked. Some current skin operations explicitly refuse reload while an override is active. Do not advertise general reload safety from a successful isolated test; use a full restart when the current test protocol requires it.

---

# 30. Separate preview, Apply, and native Save

**Verified behavior:** these are distinct layers, not interchangeable descriptions of “the color changed.”

| Layer | Meaning | What must be tested |
| --- | --- | --- |
| Live preview | Temporary visual change | Cancel, timeout, selection change, context exit |
| Editor Apply | Edit retained for the current editing context | Hover restoration, radial round trip, replacement selection |
| Native Save | State accepted by the game's save flow | Reopen, then separately a full process restart |
| Display override | Temporary state on a displayed material instance | Material recreation and reapplication/restoration |

The skin investigation demonstrates the difference particularly well. In the labeled v0.2.51 snapshots:

* custom source RGB survived native Save and reopening the character, including source-fragment recreation;
* the displayed material also contained that RGB;
* the temporary displayed-material `Enable Tinting` override returned from 1 to 0.

Thus an unchanged-looking skin did not mean the RGB had been lost. The rendering switch was missing. Those specific captures did **not** establish full process-restart persistence.

Likewise, a source scalar that reads 1 before and after saving does not prove that it was serialized if the stock preset also supplies 1.

Inspect source state and displayed state independently. Property flags and generated header dumps help identify candidates, but do not establish the game's custom save/copy behavior. Generated empty implementation stubs are not the native implementation.

---

# 31. Restore only state you still own

**Implemented ownership pattern:** record original values and validated target identities before the first write. On cancellation or restoration, reacquire the target and confirm that it is still the object/state owned by the operation.

Do not overwrite:

* a later native swatch selection;
* an external change;
* a replacement slot or material instance;
* a new editing session that happens to use the same screen.

A recovery record should distinguish a successfully restored target from one that was replaced and deliberately left untouched. If recovery cannot be verified, report that explicitly and block further conflicting edits.

Colors+ also separates source-edit ownership from display availability. During a radial-selector round trip, the preview display may temporarily be unavailable or replaced while the source edit remains valid. That is not sufficient reason to erase the applied source RGB.

Use bounded rendering retries, and resume on a relevant context event rather than polling indefinitely at full intensity. Continue validating source ownership independently.

This is not a recommendation to invent a second save/discard system when native behavior already handles the tested source edits correctly.

---

# 32. Default selection may require a native handoff

**Project-specific workaround, verified in the tested Colors+ flow:** opening from Default temporarily selects an existing non-default swatch using the native selection flow, then previews the custom color.

That selection is a real editor-session change, not a harmless visual highlight. Record the previous selection before making it.

Cancellation and timeout restored Default in testing. Native hover/selection and departure from the relevant customization context must also be handled deliberately; do not force the temporary selection back after the player has made a newer intentional choice.

This technique is specific to the customization flow we tested. “Default” may represent different things in another slot or widget, so do not assume every default entry exposes a writable color fragment.

---

# 33. Mock tests do not validate native argument conversion

**Unresolved experiment: v0.2.52 skin target probe.**

The probe attempted to change a per-character scalar's material target from Outfit to the observed five-mesh layout, while preserving the parameter name, material names, scalar value, and RGB.

The setter returned, but the next validation failed:

```text
SET BEGIN | target=meshes
START FAILED | Skin material parameter changed
RESTORE FAILED | Skin material parameter changed
```

The probe never reached its verified active state. This is **not** evidence that a successfully installed target change has no visual effect.

Local mocked tests passed, but they did not prove that the native call transferred the structured argument as intended. The exact cause remains unresolved; do not present a particular marshalling explanation as established.

Lessons for future probes:

1. Verify every relevant field after a structured write, not just whether the call returned.
2. Preserve recovery information before writing.
3. Account for partial or unexpected mutation when designing restoration.
4. Do not let a strict normal-operation validator become the only path to recovering a partially changed target.
5. Keep recovery narrowly identity- and ownership-checked; do not bypass safeguards by writing to arbitrary objects.
6. If restoration cannot be verified, stop the experiment and avoid saving that session.

The v0.2.52 recovery path did not successfully handle the observed state. It needs repair before this probe becomes a reusable example.

---

# 34. Diagnostics must match the actual Lua runtime

**Verified diagnostic failure:** the first per-call tracing implementation used global `unpack`. It worked in the local test environment but was unavailable in-game, so the tracing code itself prevented the picker from opening.

The compatibility fix resolves the available unpack function explicitly:

```lua
local unpack_values = assert(table.unpack or unpack, "Lua unpack function unavailable")
```

When wrapping calls, also preserve the number of return values so nil-containing results are not silently changed.

More broadly:

* Test diagnostics in the actual game runtime, not only the local runner.
* Keep trace windows bounded by duration and call count.
* Pair native-call entry and return records.
* Identify runtime/session generations in logs.
* Distinguish Lua exceptions, failed validation, and missing native returns.
* Make clear whether a probe reached its active phase before interpreting a visual result.

Instrumentation should help isolate a failure without becoming a new unbounded workload or changing the behavior being investigated.

---

# 35. Updated practical checklist

For a new Zero Company UI editing tool:

* Preserve native structure and prefer the game's own controls and styling.
* Observe readiness; then reacquire and validate the actual target at execution time.
* Let native click/close processing retire before changing UI layers.
* Give each window and action an explicit lifecycle.
* Own hooks, delayed work, and callback generations.
* Separate source edits from temporary display state.
* Restore only changes still owned by the operation.
* Test Default, hover, selection, Apply, Cancel, timeout, and screen transitions independently.
* Test save/reopen separately from a full restart.
* Treat reload as a distinct, potentially unsupported lifecycle.
* Use bounded diagnostics and verify native writes through readback.
* Label findings by evidence strength, including failures and remaining unknowns.

The shared lesson from Character Share and Colors+ is that reliable UI modding depends as much on **ownership, timing, and recovery** as it does on creating the widgets.

