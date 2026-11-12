// This is intentionally a request-time Server Component. The marketing site
// has no client-side data dependency, but deploying it as dynamic SSR keeps
// the rendering model ready for server-provided release details or content.
export const dynamic = "force-dynamic";

const MAC_URL = "https://github.com/arjun2010-ece/EchoPrompt/releases/latest";
const PLAY_URL = "https://play.google.com/store/apps/details?id=com.talkroll.app";
// Set NEXT_PUBLIC_APP_STORE_URL to the App Store listing once the app record exists.
const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "#platforms";

const APPLE_PATH = "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701";
const PLAY_PATH = "M22.018 13.298l-3.919 2.218-3.515-3.493 3.543-3.521 3.891 2.202a1.49 1.49 0 0 1 0 2.594zM1.337.924a1.486 1.486 0 0 0-.112.568v21.017c0 .217.045.419.124.6l11.155-11.087L1.337.924zm12.207 10.065l3.258-3.238L3.45.195a1.466 1.466 0 0 0-.946-.179l11.04 10.973zm0 2.067l-11 10.933c.298.036.612-.016.906-.183l13.324-7.54-3.23-3.21z";

function StoreBadges() {
  return (
    <div className="store-badges">
      <a className="store-badge store-badge-mac" href={MAC_URL}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d={APPLE_PATH} /></svg>
        <span><small>Download for</small><b>macOS</b></span>
      </a>
      <a className="store-badge" href={APP_STORE_URL}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d={APPLE_PATH} /></svg>
        <span><small>Download on the</small><b>App Store</b></span>
      </a>
      <a className="store-badge" href={PLAY_URL}>
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d={PLAY_PATH} /></svg>
        <span><small>GET IT ON</small><b>Google Play</b></span>
      </a>
    </div>
  );
}

const platforms = [
  {
    name: "macOS",
    devices: "Mac · macOS 13 Ventura or later",
    cta: "Download for Mac",
    href: MAC_URL,
    features: ["Floating prompt over any app", "Click-through prompt window", "Auto-scroll, Voice, and Narration modes", "Scripts saved as local text files"],
  },
  {
    name: "iPhone & iPad",
    devices: "iOS and iPadOS",
    cta: "Download on the App Store",
    href: APP_STORE_URL,
    features: ["Auto-scroll, Voice, and Narration modes", "Live word-by-word voice following", "Adjustable text size, spacing, and themes", "Free to try"],
  },
  {
    name: "Android",
    devices: "Phones and tablets",
    cta: "Get it on Google Play",
    href: PLAY_URL,
    features: ["Auto-scroll, Voice, and Narration modes", "Live word-by-word voice following", "Adjustable text size, spacing, and themes", "Free to try"],
  },
];

const features = [
  { title: "Voice that follows your words", text: "The prompter tracks the script as you speak, highlights your progress, and waits when you pause or change pace." },
  { title: "Auto-scroll at your pace", text: "A steady, adjustable scroll that never touches the microphone. Ideal for quick reads and quiet rooms." },
  { title: "Follow a narration recording", text: "Import an audio file and the script is aligned to it, with pause, seek, restart, skip, and a sync offset." },
  { title: "Sections and retakes", text: "Split a script into named sections, stop at each one, then retake, continue, or jump to another section." },
  { title: "Action cues", text: "Add reminders you should see but not read aloud. Cues can appear ahead of time, or hold the session until you continue." },
  { title: "Record video with the prompter", text: "On iPhone, iPad, and Android the prompter floats over the in-app camera. Export one finished video or separate clips." },
  { title: "Floating prompt on Mac", text: "Keep your script above Zoom, Google Meet, or your editor. Place it in a corner or under the camera notch, with global shortcuts." },
  { title: "Built for comfortable reading", text: "Adjust text size, font, line spacing, margins, opacity, and reading guide. Mirror text for teleprompter glass. Light and dark looks." },
  { title: "Many languages", text: "Voice and Narration support multiple reading languages with automatic detection or manual choice. Support varies by device and language." },
];

const comparison = [
  { feature: "Auto-scroll, Voice, and Narration", mac: true, iphone: true, ipad: true, android: true },
  { feature: "Sections, retakes, and action cues", mac: true, iphone: true, ipad: true, android: true },
  { feature: "Import text/Markdown, export text", mac: true, iphone: true, ipad: true, android: true },
  { feature: "Text, font, spacing, opacity, mirror", mac: true, iphone: true, ipad: true, android: true },
  { feature: "Prompter over other apps (Zoom, Meet)", mac: true, iphone: false, ipad: false, android: false },
  { feature: "Global shortcuts and menu-bar controls", mac: true, iphone: false, ipad: false, android: false },
  { feature: "Notch and corner placement", mac: true, iphone: false, ipad: false, android: false },
  { feature: "In-app camera recording with the prompter", mac: false, iphone: true, ipad: true, android: true },
  { feature: "Export video or separate clips, save to gallery", mac: false, iphone: true, ipad: true, android: true },
];

const useCases = [
  { title: "Video creators", text: "Record YouTube, Reels, and course videos while looking at the lens, one section at a time." },
  { title: "Meetings and webinars", text: "Keep talking points above your call window so you can present with your eyes up." },
  { title: "Speeches and rehearsal", text: "Practice with voice following, then rehearse against a recording of your narration." },
  { title: "Demos and training", text: "Use action cues to remember when to click, pause, or switch screens, without saying them aloud." },
];

const modes = [
  {
    number: "01",
    name: "Auto-scroll",
    eyebrow: "Set the rhythm",
    text: "Choose a comfortable reading pace, then let the script move smoothly while you focus on the delivery.",
    detail: "Live text size and line spacing controls",
  },
  {
    number: "02",
    name: "Voice",
    eyebrow: "Speak naturally",
    text: "TalkRoll follows the words you say, pauses when you pause, and keeps the next line waiting for you.",
    detail: "Active word tracking with clear reading feedback",
  },
  {
    number: "03",
    name: "Narration",
    eyebrow: "Rehearse in sync",
    text: "Play a local voice-over or rehearsal recording and let the prompter follow its recognized words.",
    detail: "Local audio playback with synchronized progress",
  },
];

const questions = [
  {
    question: "Which platforms does TalkRoll support?",
    answer:
      "TalkRoll is a native app for macOS 13 Ventura and later, iPhone, iPad, and Android. Use the download buttons at the top of this page.",
  },
  {
    question: "Is TalkRoll free?",
    answer:
      "You can try it free. The free tier includes a limited number of saved scripts, and Pro removes that restriction. Current plans and prices are shown in the app and the store listing.",
  },
  {
    question: "How does Voice mode work?",
    answer:
      "Voice mode listens while the prompter is open and follows the words of your script, highlighting your progress. You can pause or change pace naturally. It tracks the words you read; it does not respond to spoken commands such as \"go back\".",
  },
  {
    question: "What is Narration mode?",
    answer:
      "Import a prerecorded audio file and TalkRoll aligns your script with it, then follows the recording as it plays. You get pause, seek, restart, skip, and a sync offset. On mobile, the recording can be used as the audio of your video.",
  },
  {
    question: "Can I record video with TalkRoll?",
    answer:
      "Yes, on iPhone, iPad, and Android. The prompter floats over the in-app camera so you can read and see yourself at once. Record a whole script or one section at a time, then export one video or separate clips. Camera recording works with Voice and Narration modes, not Auto-scroll.",
  },
  {
    question: "Can I keep the prompt over Zoom or Google Meet?",
    answer:
      "Yes, on Mac. The prompt is a floating window you can move, resize, or place in a corner or near the camera. Click-through mode lets you use the app beneath it. A setting tries to hide the prompt from screen sharing and recordings, though that depends on the capture app and system.",
  },
  {
    question: "What are sections and action cues?",
    answer:
      "Sections divide a script into named parts so you can retake just one. Action cues are reminders you see but do not read aloud, such as \"pause\" or \"show slide\". A hold cue can pause the session until you continue.",
  },
  {
    question: "Which languages are supported?",
    answer:
      "Voice and Narration support multiple reading languages, with automatic detection or manual selection. Supported languages and recognition quality vary by platform, operating system, installed language packs, and device. Some packs need an initial download.",
  },
  {
    question: "Does it work offline, and is it private?",
    answer:
      "Scripts are stored locally and no account is required. Auto-scroll needs no microphone. On Apple devices, downloaded language packs can process speech on the device. Android may use the device's online speech service for some languages. Purchases and some features need internet access.",
  },
  {
    question: "When does it ask for permissions?",
    answer:
      "Only Voice mode needs microphone and speech recognition access, and video recording needs camera access. Auto-scroll does not request any of these.",
  },
  {
    question: "Can I bring in my own script?",
    answer:
      "Yes. Write in the app, or import plain text and Markdown files, and export scripts as plain text. On Mac, scripts are also saved as readable text files in Documents/TalkRoll Scripts.",
  },
];

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: "TalkRoll",
      applicationCategory: "ProductivityApplication",
      operatingSystem: "macOS 13 Ventura or later, iOS, iPadOS, Android",
      description:
        "A native teleprompter for Mac, iPhone, iPad, and Android with smooth scrolling, live voice following, and recorded-audio script synchronization.",
      featureList: [
        "Smooth auto-scroll teleprompter scrolling",
        "Live voice-controlled script following",
        "Narration-synchronized script following",
        "Adjustable text size and line spacing",
        "Local plain-text script storage",
        "Floating click-through prompt window on Mac",
        "Section-by-section takes and action cues",
        "In-app video recording with the prompter on iPhone, iPad, and Android",
      ],
    },
    {
      "@type": "FAQPage",
      mainEntity: questions.map(({ question, answer }) => ({
        "@type": "Question",
        name: question,
        acceptedAnswer: {
          "@type": "Answer",
          text: answer,
        },
      })),
    },
  ],
};

export default function Home() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(structuredData).replace(/</g, "\\u003c"),
        }}
      />
    <main>
      <section className="hero" id="top">
        <nav className="nav shell" aria-label="Primary navigation">
          <a className="brand" href="#top" aria-label="TalkRoll home">
            <span className="brand-mark" aria-hidden="true"><img src="/icon.png" alt="" /></span>
            <span>TalkRoll</span>
          </a>
          <div className="nav-links">
            <a href="#platforms">Platforms</a>
            <a href="#features">Features</a>
            <a href="#modes">Modes</a>
            <a href="#workflow">Workflow</a>
            <a href="#faq">FAQ</a>
          </div>
          <a className="nav-cta" href="#platforms">Download <span aria-hidden="true">↗</span></a>
        </nav>

        <div className="hero-grid shell">
          <div className="hero-copy">
            <p className="kicker"><span /> Voice-activated teleprompter app</p>
            <h1>The best teleprompter<br /><em>for every script.</em></h1>
            <p className="hero-description">
              A voice-activated teleprompter that follows your words, not the clock. Free to try on Mac, iPhone, iPad, and Android.
            </p>
            <StoreBadges />
            <div className="availability" aria-label="Product availability">
              <span className="availability-dot" /> macOS
              <span className="availability-rule" /> iPhone
              <span className="availability-rule" /> iPad
              <span className="availability-rule" /> Android
              <span className="availability-rule" /> No account required
            </div>
          </div>

          <div className="prompt-stage" aria-label="TalkRoll interface preview">
            <div className="orb orb-one" />
            <div className="orb orb-two" />
            <div className="prompt-window">
              <div className="window-titlebar">
                <span className="traffic"><b /><b /><b /></span>
                <span className="window-app-brand"><img src="/icon.png" alt="" />TalkRoll</span>
                <span className="window-status">VOICE CONTROL</span>
              </div>
              <div className="window-reading">
                <p>Every clear message begins with a moment of focus.</p>
                <p>Let your ideas <mark>move at your pace,</mark> so your audience sees you, not the script.</p>
              </div>
              <div className="window-controls">
                <span className="control-pill">↙<small>Slower</small></span>
                <span className="control-play">Ⅱ <small>Listening</small></span>
                <span className="control-pill">↗<small>Faster</small></span>
              </div>
            </div>
            <p className="stage-caption"><span /> Live word following, without the rush</p>
          </div>
        </div>
        <div className="hero-baseline" />
      </section>

      <section className="platforms shell" id="platforms">
        <div className="platforms-heading">
          <p className="section-label">Native apps · Free to try</p>
          <h2>Your script follows<br />every word, everywhere.</h2>
        </div>
        <div className="platform-grid">
          {platforms.map((platform) => (
            <article className="platform-card" key={platform.name}>
              <p className="platform-devices">{platform.devices}</p>
              <h3>{platform.name}</h3>
              <ul>
                {platform.features.map((feature) => (
                  <li key={feature}><span>↗</span> {feature}</li>
                ))}
              </ul>
              <a className="button button-primary" href={platform.href}>{platform.cta} <span aria-hidden="true">↗</span></a>
            </article>
          ))}
        </div>
      </section>

      <section className="features shell" id="features">
        <p className="section-label">Everything in one teleprompter</p>
        <h2>Everything you need<br />to deliver the script.</h2>
        <div className="feature-grid">
          {features.map((f) => (
            <article key={f.title}><h3>{f.title}</h3><p>{f.text}</p></article>
          ))}
        </div>
      </section>

      <section className="compare shell" id="compare">
        <p className="section-label">Platforms at a glance</p>
        <h2>What each app does.</h2>
        <div className="compare-scroll">
          <table>
            <thead>
              <tr><th scope="col">Feature</th><th scope="col">Mac</th><th scope="col">iPhone</th><th scope="col">iPad</th><th scope="col">Android</th></tr>
            </thead>
            <tbody>
              {comparison.map((row) => (
                <tr key={row.feature}>
                  <th scope="row">{row.feature}</th>
                  {[row.mac, row.iphone, row.ipad, row.android].map((on, i) => (
                    <td key={i} className={on ? "yes" : "no"}><span aria-label={on ? "Included" : "Not included"}>{on ? "✓" : "–"}</span></td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="compare-note">Camera recording is available with Voice and Narration modes. Voice and Narration availability and accuracy depend on your device, language, and recording.</p>
      </section>

      <section className="intro shell" id="workflow">
        <p className="section-label">A more natural reading experience</p>
        <div className="intro-grid">
          <h2>Built to disappear<br />when it matters.</h2>
          <div>
            <p>
              TalkRoll gives your words a calm, considered place to live—close to the camera, above the work you are sharing, and ready when you are.
            </p>
            <a className="text-link" href="#modes">Explore the ways to present <span aria-hidden="true">→</span></a>
          </div>
        </div>
        <div className="workflow-steps">
          <article><span>01</span><h3>Write</h3><p>Paste a draft, refine your language, and save it locally as a readable text file.</p></article>
          <article><span>02</span><h3>Choose</h3><p>Select a pace that suits the moment: automatic, live voice, or narration.</p></article>
          <article><span>03</span><h3>Present</h3><p>Open the floating prompt, keep it near your camera, and give your attention to the room.</p></article>
        </div>
      </section>

      <section className="modes-section" id="modes">
        <div className="shell">
          <div className="section-heading">
            <p className="section-label">One script, three rhythms</p>
            <h2>Follow the method<br />that fits the moment.</h2>
          </div>
          <div className="mode-list">
            {modes.map((mode) => (
              <article className="mode-card" key={mode.name}>
                <span className="mode-number">{mode.number}</span>
                <div className="mode-main">
                  <p className="mode-eyebrow">{mode.eyebrow}</p>
                  <h3>{mode.name}</h3>
                  <p>{mode.text}</p>
                </div>
                <p className="mode-detail"><span>✦</span>{mode.detail}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="customize shell">
        <div className="customize-copy">
          <p className="section-label">Made for your line of sight</p>
          <h2>Your words,<br /><em className="customize-emphasis">your way.</em></h2>
          <p>Set the size, spacing, contrast, and presentation style that lets you read comfortably without breaking eye contact.</p>
          <ul>
            <li><span>↗</span> Text size from 16 to 110 pt</li>
            <li><span>↗</span> Adjustable line spacing and prompt opacity</li>
            <li><span>↗</span> Midnight, Paper, and Ember prompt themes</li>
            <li><span>↗</span> Mirror text for teleprompter glass</li>
          </ul>
        </div>
        <div className="style-preview" aria-label="Prompt customization preview">
          <div className="preview-topline"><span>Prompt appearance</span><b>◐</b></div>
          <div className="preview-script">
            <p>Make every <span>word</span> feel like your own.</p>
            <i />
            <p className="muted-line">Find your rhythm, then let the thought land.</p>
          </div>
          <div className="preview-settings">
            <div><span>Text size</span><b>50 pt</b><i><em /></i></div>
            <div><span>Line spacing</span><b>1.28×</b><i><em /></i></div>
          </div>
        </div>
      </section>

      <section className="usecases shell" id="use-cases">
        <p className="section-label">Who it is for</p>
        <h2>Made for anyone who<br />speaks from a script.</h2>
        <div className="usecase-grid">
          {useCases.map((u) => (
            <article key={u.title}><h3>{u.title}</h3><p>{u.text}</p></article>
          ))}
        </div>
      </section>

      <section className="privacy-band">
        <div className="shell privacy-grid">
          <div className="privacy-icon" aria-hidden="true">⌁</div>
          <div>
            <p className="section-label">A quieter kind of software</p>
            <h2>Your script stays close.</h2>
          </div>
          <p>TalkRoll stores scripts on your device, asks for permissions only for the mode that needs them, and never requires an account. Voice needs the microphone and speech recognition, video recording needs the camera, and Auto-scroll needs neither.</p>
        </div>
      </section>

      <section className="faq shell" id="faq">
        <div className="faq-heading">
          <p className="section-label">Good to know</p>
          <h2>Questions, answered.</h2>
        </div>
        <div className="faq-list">
          {questions.map((item, index) => (
            <details key={item.question} open={index === 0}>
              <summary>{item.question}<span aria-hidden="true">+</span></summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="download" id="download">
        <div className="shell download-inner">
          <p className="section-label">Ready when you are</p>
          <h2>Bring your next<br /><em>great take</em> closer.</h2>
          <p>Download the native app, open your script, and make space for the delivery.</p>
          <StoreBadges />
          <small>Mac, iPhone, iPad, and Android · Personal-use license</small>
        </div>
      </section>

      <footer className="footer">
        <div className="shell footer-inner">
          <div className="footer-branding">
            <a className="brand" href="#top"><span className="brand-mark" aria-hidden="true"><img src="/icon.png" alt="" /></span><span>TalkRoll</span></a>
            <p>Made in Portugal by Arjun Sah <span aria-hidden="true">·</span> © 2026 TalkRoll</p>
          </div>
          <div className="footer-actions">
            <nav className="footer-links" aria-label="Footer navigation">
              <a href="#platforms">Platforms</a>
              <a href="#modes">Modes</a>
              <a href="#faq">FAQ</a>
              <a href="/privacy">Privacy</a>
              <a href="/terms">Terms</a>
              <a href="#top">Back to top ↑</a>
            </nav>
            {/*
              Replace this placeholder with the real channel URL when it is ready:
              <a className="footer-youtube" href="https://youtube.com/@your-channel" aria-label="TalkRoll on YouTube">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21.6 7.2a2.9 2.9 0 0 0-2-2C17.8 4.7 12 4.7 12 4.7s-5.8 0-7.6.5a2.9 2.9 0 0 0-2 2A30 30 0 0 0 2 12a30 30 0 0 0 .4 4.8 2.9 2.9 0 0 0 2 2c1.8.5 7.6.5 7.6.5s5.8 0 7.6-.5a2.9 2.9 0 0 0 2-2A30 30 0 0 0 22 12a30 30 0 0 0-.4-4.8ZM9.7 15.3V8.7l5.7 3.3-5.7 3.3Z" /></svg>
              </a>
            */}
            <div className="footer-youtube-placeholder" role="img" aria-label="YouTube link coming soon">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21.6 7.2a2.9 2.9 0 0 0-2-2C17.8 4.7 12 4.7 12 4.7s-5.8 0-7.6.5a2.9 2.9 0 0 0-2 2A30 30 0 0 0 2 12a30 30 0 0 0 .4 4.8 2.9 2.9 0 0 0 2 2c1.8.5 7.6.5 7.6.5s5.8 0 7.6-.5a2.9 2.9 0 0 0 2-2A30 30 0 0 0 22 12a30 30 0 0 0-.4-4.8ZM9.7 15.3V8.7l5.7 3.3-5.7 3.3Z" /></svg>
              <span>Coming soon</span>
            </div>
          </div>
        </div>
      </footer>
    </main>
    </>
  );
}
