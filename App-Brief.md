# EchoPrompter: App Brief

This document describes the current Flutter app as implemented in the repository. It is a product brief for an App Store optimization agent, not final store copy. Confirm the features and commercial terms in the specific release before making claims in a listing; development documentation also contains proposals and older implementation notes.

## What the app does

EchoPrompter is a teleprompter for writing, rehearsing, presenting, and recording from a script. It helps people keep their place and maintain eye contact with a camera while speaking naturally. Users can scroll at a steady pace, have the text follow their speech, or follow an existing narration recording. They can also divide a script into sections, add production cues, and retake individual sections.

The current product scope is **iPhone, iPad, Mac, and Android**. The repository contains Windows-related code, but recent product documentation says Windows has been dropped from the current scope. Do not assume the app is available in any particular store or market until the release is confirmed.

## Who it can help

- Video creators, vloggers, educators, and course creators recording scripted content.
- Professionals presenting in online meetings, webinars, demos, and presentations.
- Speakers rehearsing speeches, interviews, training material, or talking points.
- Anyone who wants to read a script near a camera or break a recording into manageable takes.

These are use cases, not claims about specific integrations or customer groups.

## Main features

### Three ways to follow a script

- **Auto-scroll:** The text scrolls at an adjustable, steady pace. This mode does not use the microphone.
- **Voice:** The prompter follows the user's spoken words and highlights progress, allowing the presenter to pause or change pace naturally. It listens while the prompter is open and needs microphone and speech recognition access.
- **Narration:** Import a prerecorded audio file and the app aligns the script with it, then follows the recording as it plays. Playback controls include pause, seek, restart, and skipping backward or forward. A sync offset can help adjust timing. Availability and accuracy depend on the device, language, and recording.

Voice following means tracking the words of the script; do not advertise spoken navigation commands such as “go back” or “go next” as current features.

### Scripts, sections, and cues

- Write and edit scripts in the app, save them locally, and return to recent scripts. Import plain text or Markdown files and export scripts as plain text.
- Read an entire script continuously or divide it into named sections. A section-by-section run stops at each section, with controls to retake it, continue, or jump to another section.
- Add **action cues** for reminders that should be seen rather than spoken. Cues can appear ahead of time, and an optional hold cue pauses the session until the presenter continues.
- On Mac, a separate notes area can hold reference material such as talking points and checklists; notes are not presented as scripts.

### Video recording on iPhone, iPad, and Android

- On iOS, iPadOS, and Android, the prompter floats over EchoPrompter's in-app camera preview while users record with the front or back camera. This lets them read the script and see the camera view at the same time. The camera is available with Voice and Narration modes; it is not currently offered with Auto-scroll.
- Record a whole script or capture a section at a time, retaking individual sections as needed. The app can export the selected section takes as one finished video or as separate clips, and offers saving to the device gallery and sharing.
- Narration mode can use the imported recording as the audio for the video. The recorded narration is not a live voice recording.

### Mac presentation tools

- On macOS, the prompter / above other apps and windows, so users can follow their script while using tools such as Zoom, Google Meet, or a video editor. It can be a movable, resizable floating window, sit in a corner, or appear near the camera at the top of the screen, including under a MacBook notch where available.
- Use adjustable opacity, menu-bar controls, and customizable global keyboard shortcuts while working in other apps.
- A setting attempts to hide the prompter from screen sharing and recordings. This depends on the capture app and system behavior, so do not promise invisibility in every situation.
- Optional sound and/or visual markers help identify takes during editing. A take list can be copied or shared during the current run.

### Reading comfort and languages

- Adjust text size, font, line spacing, margins, background opacity, and reading guide. Mirror text for compatible teleprompter glass setups. The app also offers light and dark appearance options.
- Voice and Narration support multiple reading languages, with automatic language detection or manual selection. Supported languages and recognition quality vary by platform, operating system, installed language packs, and device. Some language packs require an initial download.

## Privacy, connectivity, and permissions

- Scripts are stored locally on the device. Auto-scroll does not need microphone access.
- Voice mode needs microphone and speech recognition permissions. Video recording needs camera access, with additional permissions depending on the mode and where the video is saved.
- On Apple devices, supported language packs can be downloaded for on-device speech processing. Android speech recognition may use the device's online speech service for some languages or configurations. Some features and purchases may require internet access.
- Do not claim that all processing is always on-device, that every feature works offline, or that the app is a Safari-based PWA.

## Free and paid access

The code supports a free tier and Pro purchases, but enforcement depends on the release build and store configuration. When enabled, the free tier supports five saved scripts and a limited pool of replacements; Pro removes the free-script restriction. Monthly, yearly, and lifetime purchase options are implemented in the purchase flow. Confirm availability, limits, prices, and store product configuration before publishing any pricing or subscription claims.

## Useful positioning themes

Teleprompter and video script reader; voice-following teleprompter; hands-free presentation; prerecorded narration; script rehearsal; camera recording; section-by-section takes; Mac webcam overlay; presenter action cues. Use these as starting points for research, not as verified keyword rankings or claims of exclusivity.
