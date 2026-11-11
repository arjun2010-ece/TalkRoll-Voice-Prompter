import 'package:flutter/material.dart';

/// What the reader is getting ready for (the tour's first question). It picks the practice line the demo reads and the
/// wording of the next screens. Nothing from it is saved as a script.
class OnboardingGoal {
  const OnboardingGoal({
    required this.id,
    required this.glyph,
    required this.tone,
    required this.label,
    required this.hint,
    required this.when,
    required this.noun,
    required this.line,
  });

  /// Stored with the answers; never shown.
  final String id;

  /// The card's line icon, drawn in its [tone].
  final GoalGlyph glyph;
  final BadgeTone tone;

  /// Short, for the goal card; [hint] is the line under it.
  final String label;
  final String hint;

  /// Finishes "What gets in the way …?", e.g. "when you film".
  final String when;

  /// "video", for "Keep every video script with TalkRoll Pro". Empty for any script.
  final String noun;

  /// The practice line the demo reads, something this reader might really say.
  final String line;
}

/// The goal cards' line icons, drawn by `GoalGlyphPainter` to match the design (no icon font has them).
enum GoalGlyph { movieCamera, mortarboard, easel, handheldMic, studioMic, sparkles, people, eye, listCheck, retake, gauge, book, waveform, autoScroll, narration, micLine }

/// A goal badge's colours. The dark ones are sampled from the design; on light the icon is a deeper shade of the same
/// hue on a pale badge, every pair about 4.2–5.2:1.
class BadgeTone {
  const BadgeTone({required this.darkIcon, required this.darkBadge, required this.lightIcon, required this.lightBadge});
  final Color darkIcon;
  final Color darkBadge;
  final Color lightIcon;
  final Color lightBadge;

  Color icon(Brightness b) => b == Brightness.dark ? darkIcon : lightIcon;
  Color badge(Brightness b) => b == Brightness.dark ? darkBadge : lightBadge;

  static const sky = BadgeTone(darkIcon: Color(0xFF6CCCF4), darkBadge: Color(0xFF274664), lightIcon: Color(0xFF1574A6), lightBadge: Color(0xFFE4F5FC));
  static const lavender = BadgeTone(darkIcon: Color(0xFFC4B4F8), darkBadge: Color(0xFF3D3E5E), lightIcon: Color(0xFF6B4FCF), lightBadge: Color(0xFFEEE9FC));
  static const aqua = BadgeTone(darkIcon: Color(0xFF84F8E8), darkBadge: Color(0xFF28474E), lightIcon: Color(0xFF0E8276), lightBadge: Color(0xFFE1F8F4));
  static const peach = BadgeTone(darkIcon: Color(0xFFF8D0AC), darkBadge: Color(0xFF3F3E43), lightIcon: Color(0xFFA95B1A), lightBadge: Color(0xFFFBEFE4));
  static const rose = BadgeTone(darkIcon: Color(0xFFF4B0BC), darkBadge: Color(0xFF423846), lightIcon: Color(0xFFB23A55), lightBadge: Color(0xFFFAE5E9));
  /// Muted badge tones for the question list: a white line icon on a flat colour, the same in both appearances.
  static const plum = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF524D68), lightIcon: Colors.white, lightBadge: Color(0xFF6A6486));
  static const steel = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF425D7E), lightIcon: Colors.white, lightBadge: Color(0xFF4F6F95));
  static const clay = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF635651), lightIcon: Colors.white, lightBadge: Color(0xFF86736C));
  static const jade = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF3E7067), lightIcon: Colors.white, lightBadge: Color(0xFF3F8478));
  static const iris = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF534F6D), lightIcon: Colors.white, lightBadge: Color(0xFF6B6690));
  static const moss = BadgeTone(darkIcon: Colors.white, darkBadge: Color(0xFF40675E), lightIcon: Colors.white, lightBadge: Color(0xFF47796C));

  /// The three reading modes on the last screen: Voice, Auto-scroll and Narration.
  static const modeVoice = BadgeTone(darkIcon: Color(0xFF59CAF5), darkBadge: Color(0xFF203148), lightIcon: Color(0xFF1574A6), lightBadge: Color(0xFFE4F5FC));
  static const modeAuto = BadgeTone(darkIcon: Color(0xFF70F4D0), darkBadge: Color(0xFF20383C), lightIcon: Color(0xFF0E8276), lightBadge: Color(0xFFE1F8F4));
  static const modeNarration = BadgeTone(darkIcon: Color(0xFFD3B7FA), darkBadge: Color(0xFF34324E), lightIcon: Color(0xFF6B4FCF), lightBadge: Color(0xFFEEE9FC));

  static const periwinkle = BadgeTone(darkIcon: Color(0xFFB4BCF8), darkBadge: Color(0xFF333C59), lightIcon: Color(0xFF4553C9), lightBadge: Color(0xFFE7E9FC));
}

/// A frustration the reader can pick, and how TalkRoll answers it on the next screen.
class OnboardingPain {
  const OnboardingPain({required this.id, required this.label, required this.fix, required this.icon, this.glyph, required this.tone});
  final String id;
  final String label;
  final String fix;
  final IconData icon;

  /// The line icon on the question screen, drawn to match the design; [icon] is used on the solution screen.
  final GoalGlyph? glyph;

  /// The badge colour on the question screen (white line icon on a muted tone).
  final BadgeTone tone;
}

// --- Goals -------------------------------------------------------------------------------------------------------

const _videos = OnboardingGoal(
  id: 'videos',
  glyph: GoalGlyph.movieCamera,
  tone: BadgeTone.sky,
  label: 'Videos',
  hint: 'YouTube, Reels, TikTok',
  when: 'when you film',
  noun: 'video',
  line: "Hi, I'm glad you're here. In this video I'll show you something I've wanted to share for a while.",
);

const _lessons = OnboardingGoal(
  id: 'lessons',
  glyph: GoalGlyph.mortarboard,
  tone: BadgeTone.lavender,
  label: 'Teaching',
  hint: 'Lessons and courses',
  when: 'when you teach on camera',
  noun: 'lesson',
  line: "Welcome to this lesson. By the end of it, you'll know how to take the first step on your own.",
);

const _presentations = OnboardingGoal(
  id: 'presentations',
  glyph: GoalGlyph.easel,
  tone: BadgeTone.aqua,
  label: 'Presentations',
  hint: 'Pitches, demos, work talks',
  when: 'when you present',
  noun: 'presentation',
  line: 'Thanks for joining me today. I want to show you one idea that could change how we work this year.',
);

const _speeches = OnboardingGoal(
  id: 'speeches',
  glyph: GoalGlyph.handheldMic,
  tone: BadgeTone.peach,
  label: 'Speeches',
  hint: 'Weddings, events, toasts',
  when: 'when you give a speech',
  noun: 'speech',
  line: 'Good evening, everyone. Thank you all for being here tonight. It really means a lot to me.',
);

const _voiceover = OnboardingGoal(
  id: 'voiceover',
  glyph: GoalGlyph.studioMic,
  tone: BadgeTone.rose,
  label: 'Voice-overs',
  hint: 'Narration and podcasts',
  when: 'when you record your voice',
  noun: 'voice-over',
  line: 'Every good story starts with a single moment. This is the story of how ours began.',
);

const _calls = OnboardingGoal(
  id: 'calls',
  glyph: GoalGlyph.people,
  tone: BadgeTone.peach,
  label: 'Video calls',
  hint: 'Meetings and interviews',
  when: "when you're on a call",
  noun: 'meeting',
  line: "Hi everyone, thanks for making the time. I'll walk you through where we are and what I need from you today.",
);

const _other = OnboardingGoal(
  id: 'other',
  glyph: GoalGlyph.sparkles,
  tone: BadgeTone.periwinkle,
  label: 'Something else',
  hint: 'Anything you read aloud',
  when: 'when you read from a script',
  noun: '',
  line: "Hi, thanks for taking a moment to listen. I'll keep this short and get straight to the point.",
);

// --- iPhone, iPad and Android -------------------------------------------------------------------------------------

const mobileGoals = [_videos, _lessons, _presentations, _speeches, _voiceover, _other];

const mobilePains = [
  OnboardingPain(
    id: 'eyes',
    label: 'I keep looking away from the camera',
    fix: 'Your script floats over the camera preview, so your eyes stay near the lens.',
    icon: Icons.visibility_outlined,
    glyph: GoalGlyph.eye,
    tone: BadgeTone.plum,
  ),
  OnboardingPain(
    id: 'place',
    label: 'I lose my place in the script',
    fix: 'Voice mode lights up each word you say and waits when you pause.',
    icon: Icons.playlist_add_check,
    glyph: GoalGlyph.listCheck,
    tone: BadgeTone.steel,
  ),
  OnboardingPain(
    id: 'retakes',
    label: 'One slip and I redo the whole take',
    fix: 'Record one section at a time and retake only the part you fumbled.',
    icon: Icons.replay,
    glyph: GoalGlyph.retake,
    tone: BadgeTone.clay,
  ),
  OnboardingPain(
    id: 'pace',
    label: 'Scrolling text goes too fast or too slow',
    fix: 'Voice mode moves at your speed. Prefer a steady scroll? You set the pace.',
    icon: Icons.speed,
    glyph: GoalGlyph.gauge,
    tone: BadgeTone.jade,
  ),
  OnboardingPain(
    id: 'memorise',
    label: 'Learning my lines takes forever',
    fix: 'No memorising. Read naturally while TalkRoll keeps your place.',
    icon: Icons.menu_book_outlined,
    glyph: GoalGlyph.book,
    tone: BadgeTone.iris,
  ),
  OnboardingPain(
    id: 'stiff',
    label: 'I sound stiff when I read',
    fix: 'Sections and action cues build in pauses and smiles, so it sounds less read.',
    icon: Icons.graphic_eq,
    glyph: GoalGlyph.waveform,
    tone: BadgeTone.moss,
  ),
];

// --- macOS ---------------------------------------------------------------------------------------------------------

const desktopGoals = [_calls, _videos, _presentations, _lessons, _voiceover, _other];

const desktopPains = [
  OnboardingPain(
    id: 'eyes',
    label: 'I look at my notes instead of the camera',
    fix: 'Your script sits right under the camera, so you keep eye contact.',
    icon: Icons.visibility_outlined,
    glyph: GoalGlyph.eye,
    tone: BadgeTone.plum,
  ),
  OnboardingPain(
    id: 'buried',
    label: 'My notes get buried under other windows',
    fix: 'The prompter floats above your call, your slides and every other window.',
    icon: Icons.picture_in_picture_alt_outlined,
    tone: BadgeTone.clay,
  ),
  OnboardingPain(
    id: 'share',
    label: 'I worry my notes will show when I share my screen',
    fix: 'It can hide from screen sharing in most apps, though not in every one.',
    icon: Icons.visibility_off_outlined,
    tone: BadgeTone.iris,
  ),
  OnboardingPain(
    id: 'place',
    label: 'I lose my place when I look up',
    fix: 'Voice mode lights up each word you say and waits when you pause.',
    icon: Icons.playlist_add_check,
    glyph: GoalGlyph.listCheck,
    tone: BadgeTone.steel,
  ),
  OnboardingPain(
    id: 'pace',
    label: 'Scrolling text goes too fast or too slow',
    fix: 'Voice mode moves at your speed. Prefer a steady scroll? You set the pace.',
    icon: Icons.speed,
    glyph: GoalGlyph.gauge,
    tone: BadgeTone.jade,
  ),
  OnboardingPain(
    id: 'stiff',
    label: 'I sound like I am reading',
    fix: 'Sections and action cues build in pauses and smiles, so it sounds less read.',
    icon: Icons.graphic_eq,
    glyph: GoalGlyph.waveform,
    tone: BadgeTone.moss,
  ),
];
