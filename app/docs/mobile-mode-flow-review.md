# Mobile: simplifying how the reading mode, camera and audio file are chosen

Status: discussion and proposal, 2026-10-27. **No code was changed for this document.**
Scope: iPhone, iPad and Android (`app/lib/features/read`, `studio/start_options.dart`, `video`).

---

## 1. What is wrong today

The flow has grown by adding one control at a time. Walking it as a user:

1. Write a script, press **Start…**. A sheet (**Start options**) offers Normal / Voice / Audio, and in Voice or Audio also *Voice only | Voice + camera*, *Front | Back*, and the audio file.
2. Normal mode opens the **reader**.
3. In the reader the settings icon opens **Reading settings**. It holds the text options **and** a second copy of the mode choice (Normal / Voice / Audio, audio file).
4. Changing the mode there changes the screen *behind* the sheet (the dock, the Play behaviour, the buttons), while the sheet is still open.
5. Voice and Audio have a *Voice only | Voice + camera* switch on the reader and on the camera screen, and a camera button used to sit on the top bar.

The result is the same decision (how to read) made in three places, with different shapes each time:

| Place | Mode | Camera | Audio file | Front/Back |
|---|---|---|---|---|
| Start options | yes | yes | yes | yes |
| Reading settings (reader) | yes | no | yes | no |
| Reader dock / camera screen | no | yes (switch) | no | flip button only |

### The root cause

**"Mode" is doing three jobs at once**, and only one of them is really a mode:

1. **How the prompter follows you** (Normal scrolls, Voice follows your voice, Audio follows a recording). This is the real mode.
2. **What it needs to follow** (Audio needs a file; Voice needs the microphone). This is setup, and only matters for one mode.
3. **Whether video is recorded** (the camera). This is not a mode at all. It is an *output* that Voice and Audio happen to allow.

Mixing these into the settings of a screen you are already reading on is the complication. Text size is a *how it looks* setting you adjust while reading. Mode, audio file and camera are *how this session works* decisions that change what the whole screen is.

Two things make the current design feel heavier than it is:

- **The sheet changes the screen it floats over.** Picking Voice swaps the dock and the Play behaviour behind the sheet, and Audio then demands a file. The user cannot see the result until the sheet closes.
- **Voice and Audio are really "start a different kind of session"**, but they are presented as a tweak (a segmented control among sliders).

---

## 2. Principles to decide with

1. **One decision, one place.** Mode, audio file and camera are chosen in one screen, never split across screens.
2. **Settings are for looks.** The settings icon in the reader should only hold things that change how the text looks or is mirrored, which is safe to adjust while reading.
3. **Nothing changes behind an open sheet** unless the user confirms.
4. **The reader shows what is active, and offers the way to change it**, without repeating the controls.
5. **No dead ends.** Every mode on offer must be usable or say, before it is chosen, what is missing.

---

## 3. Options

### Option A: Mode is chosen only before reading

Reading settings holds text options only. To change the mode the user goes back (close the reader) and picks it in Start options.

- **Pros:** simplest possible. One place for mode, camera and audio file. No sheet that changes the screen behind it. Least code.
- **Cons:** switching mode mid-session costs a round trip (close, change, Start again), and the reading position is lost unless we restore it. Trying Voice after starting in Normal feels slow.
- **Fits when:** people mostly know their mode before they start.

### Option B: A dedicated "Mode" control, separate from settings (recommended)

Keep Reading settings text-only. Add one **mode chip** to the reader's top bar that always shows the current mode, for example `Normal`, `Voice`, `Voice · Camera`, `Audio · Camera`. Tapping it opens a **"How to read" sheet**, which is the *same* sheet as Start options (same widget): mode, then the sections that belong to the chosen mode, then a button.

- **Pros:** one mental model (Start options and Mode are the same sheet). The reader's settings stay light. The chip also tells you at a glance what the session is doing. Position can be kept.
- **Cons:** one extra control on the top bar; the sheet needs an explicit apply button so the screen behind does not change early (see section 4).
- **Fits when:** people experiment with modes while reading, which is likely for a prompter.

### Option C: Keep the mode inside Reading settings, but make it a real section

When Voice or Audio is selected in the sheet, its own sub-section appears right there (Voice: voice only / voice + camera; Audio: file, voice only / voice + camera), and the screen behind changes when the sheet closes.

- **Pros:** closest to today. One sheet.
- **Cons:** the sheet changes height and meaning depending on the mode, and mixes "how it looks" with "how it works". It still changes the screen behind it, so it needs an apply button anyway, which makes it Option B inside a sheet that also holds text sliders. Longest sheet, most scrolling on a phone.
- **Verdict:** workable, but it keeps the root problem.

### Option D: A separate full-screen "Setup" step before reading

Start opens a page (not a sheet) with only the session choices: mode, mode's sub-options, camera, then **Begin**. The reader has only a **Change mode** action that returns to that page.

- **Pros:** the clearest separation: setup is one screen, reading is another. Plenty of room for the audio file, camera and a short explanation for each mode.
- **Cons:** one more screen on every start for people who always use Normal; heavier than a sheet.
- **Fits when:** the app grows more session options (languages, video quality, take settings).

### Option E: Treat the camera as a switch on the reader, not as part of the mode

Mode stays Normal / Voice / Audio. A single **Record** control on the reader (Voice and Audio only) opens the camera, and a single **Stop** returns. No "Voice only | Voice + camera" setting anywhere.

- **Pros:** the camera stops being a setting; it is an action.
- **Cons:** loses the "I will record" intent before starting (permission explainer, front/back choice up front), and the camera screen would still need its own way back to voice-only.
- **Verdict:** a good idea to combine with B for the *entry* to the camera, but not enough on its own.

---

## 4. Recommendation

**Option B, with these simplifications.** It answers the observation that Voice and Audio are different: they get their own sub-sections, in one place, and the settings sheet is no longer involved.

### 4.1 The "How to read" sheet (same as Start options)

```
How to read
  [ Normal | Voice | Audio ]
  one line explaining the chosen mode

  Normal  -> Speed slider
  Voice   -> [ Voice only | Voice + camera ]
  Audio   -> Recording: file card (choose / change / checking / can't read)
             [ Voice only | Voice + camera ]

  [ Start ]            (in Start options)
  [ Use <mode> ]       (opened from the reader)
```

- **Nothing behind the sheet changes until the button is pressed.** Choosing a mode inside the sheet only updates the sheet. The reader changes when the user confirms.
- **Audio's Start / Use button stays disabled until a recording is ready**, with the same captions as today.
- **Voice + camera on confirm** opens the camera screen; **voice only** stays on (or returns to) the reader.
- **Front or back is dropped from this sheet.** The camera screen already has a Flip button, and "Start with…" repeated the same choice in a second place. One place (Flip) is simpler, and the front camera stays the default.

### 4.2 The reader

- Top bar: **close, status pill, mode chip, settings (Aa/tune)**. The mode chip replaces the "Voice only | Voice + camera" switch on the dock, so there is one control for the whole choice.
- Reading settings: **text only**. Size, font, line spacing, margins, overlay, reading guide, progress, sections, Reset, plus Mirror and Rotate. A plain **Done**.
- Dock: Restart, Play, and the stepper (speed in Normal, text size in Voice and Audio), with the progress line.

### 4.3 The camera screen

- Top bar: **close, status pill, mode chip (`Voice · Camera`), edit, settings**.
- The mode chip is **locked while recording**, with the message "Stop the recording to change this."
- Choosing *Voice only* in the sheet from here returns to the reader. Choosing another mode switches the session.
- Bottom, within thumb reach: Flip, Record, Pause or options. No second switch.

### 4.4 Where the old controls go

| Today | After |
|---|---|
| Mode in Reading settings | Removed. Lives in the "How to read" sheet, opened by the mode chip. |
| "Voice only \| Voice + camera" on the dock and camera screen | Removed. Part of the sheet. |
| "Start with Front \| Back" | Removed. Flip button only. |
| Camera button on the reader top bar | Removed. The mode chip replaces it. |
| "Done" turning into "Open camera" | Removed (already gone). |

### 4.5 What happens to position and playback when the mode changes

- Mode changes **keep the reading position** (the current word index), so switching from Normal to Voice continues where the reader is.
- A running session is **paused** while the sheet is open and starts again on confirm.

---

## 5. If we went with the other options

- **Option A** is the least work: delete the mode and file sections from Reading settings, and keep Start options as the only place. It can be done first and replaced by B later without rework, because B reuses the same sheet.
- **Option D** is worth revisiting if more session options are added; the "How to read" sheet content can be moved into a page unchanged.
- **Option C** is not recommended: it is the current design with better labels.

---

## 6. Notes that apply to every option

- **Voice and Audio need speech recognition on the device.** Android emulators and iOS simulators usually have none, so Voice and Audio cannot follow speech there. The app should keep both modes selectable and recover with a clear message (a "Use Normal mode" action) instead of hiding them. This is already in place.
- **The camera does not apply to Normal mode** (Normal scrolls without the microphone). Allowing a camera with Normal scrolling would be a separate product decision.
- **Colors on the camera and reader chrome** should be one set: translucent charcoal controls with white icons, blue for the selected state, red only for Record and the REC pill, amber only for Pro and warnings. The mobile theme's tonal buttons are now neutral for this reason.

---

## 7. Suggested order of work (if Option B is chosen)

1. Extract the "How to read" sheet from Start options so it can be opened with an *apply* button label (Start / Use Voice).
2. Add the mode chip to the reader and camera top bars; remove the dock switch, the camera-screen switch and the camera top-bar button.
3. Reduce Reading settings to text and mirror options.
4. Drop *Start with Front | Back* from the sheet; keep Flip.
5. Keep the reading position when the mode changes; pause while the sheet is open.
6. Update the mobile design canvas (reader, camera, Start options) to match, then implement.

## 8. Questions to settle

1. Option A first, then B, or go straight to B?
- Go straight to B.
2. Is dropping *Start with Front | Back* acceptable (Flip only)?
- Yes
3. Should the mode chip be tappable on the camera screen while paused, or only before recording starts? (Recommended: before recording starts only, as the camera cannot change mid-take.)
- Have it before recording starts. If done after recording in progress then open a dialog that says Finish/Terminate this recording and buttons of save and continue, discard and continue.
