import type { Metadata } from "next";
import LegalPage, { type LegalSection } from "../../components/LegalPage";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How TalkRoll handles your scripts, camera, microphone and speech: on your device, with no account.",
  alternates: { canonical: "/privacy" },
};

const email = "arjun@talkroll.app";

const sections: LegalSection[] = [
  {
    id: "summary",
    title: "The short version",
    body: (
      <>
        <p>TalkRoll is built so your words stay with you. There is no account, and your scripts, recordings and transcripts are kept on your device. We do not sell your data, and we do not run advertising or tracking.</p>
        <ul>
          <li>Scripts are stored on your device and are never uploaded by us.</li>
          <li>Camera, microphone and speech recognition are used only for the feature you choose, and only after you allow them.</li>
          <li>Crash reports are off unless you turn them on, and never include your scripts.</li>
          <li>Purchases are handled by the App Store or Google Play, not by us.</li>
        </ul>
      </>
    ),
  },
  {
    id: "who",
    title: "Who we are",
    body: (
      <p>TalkRoll is made by Arjun Sah in Portugal. For this policy, that is the controller of the personal data described below. You can reach us at <a href={`mailto:${email}`}>{email}</a>.</p>
    ),
  },
  {
    id: "stays",
    title: "What stays on your device",
    body: (
      <>
        <p>These never leave your device through TalkRoll:</p>
        <ul>
          <li><b>Your scripts and notes.</b> On a Mac they are plain text files in <code>Documents/TalkRoll Scripts</code>. On a phone they are kept in the app's own storage.</li>
          <li><b>Narration recordings</b> you choose. The file is copied into the app's storage and read on the device to find the timing of your words. Transcripts are kept only to avoid doing the work twice.</li>
          <li><b>Your settings</b>, such as text size, theme, language and shortcuts.</li>
          <li><b>Videos you record.</b> They are saved to your photo library or gallery when you ask, and are yours to keep, share or delete.</li>
        </ul>
      </>
    ),
  },
  {
    id: "permissions",
    title: "Camera, microphone and speech",
    body: (
      <>
        <p>TalkRoll asks for each permission only when a feature needs it. Auto-scroll uses none of them.</p>
        <ul>
          <li><b>Microphone</b> is used by Voice mode to follow what you say, and to record your video with sound.</li>
          <li><b>Camera</b> is used only when you record a video while you read.</li>
          <li><b>Speech recognition</b> is used by Voice mode, and by Narration to align a recording with your script.</li>
          <li><b>Photos or gallery</b> access is used only to save the videos you record.</li>
        </ul>
        <p>On Apple devices, speech is processed on the device where your language supports it. The first time you use some languages, the system may download that language's speech pack from Apple. On Android, TalkRoll prefers the on-device recogniser. If your device does not offer one, Android's built-in recogniser is used, and depending on your device and language it may send audio to Google. That processing is governed by Google's own policies, not by ours. We never receive your audio.</p>
      </>
    ),
  },
  {
    id: "collect",
    title: "What we collect",
    body: (
      <>
        <p>By default, nothing. TalkRoll has no account, no sign-in and, at the time of writing, no usage analytics.</p>
        <p><b>Crash reports (optional).</b> In Settings you can turn on “Send crash reports”. It is off by default. When on, technical details about a crash are sent to our error-reporting provider, Sentry. We configure it not to attach personal information, screenshots or your scripts. You can turn it off at any time; the change applies the next time the app starts.</p>
        <p><b>Messages you send us.</b> If you email us, we receive your email address and whatever you write, and we use it only to reply.</p>
      </>
    ),
  },
  {
    id: "purchases",
    title: "Purchases and Pro",
    body: (
      <>
        <p>TalkRoll has a free plan and an optional Pro upgrade. Payment is handled entirely by Apple (App Store) or Google (Google Play). We never see your card or payment details. The store tells the app whether Pro is active, and the app keeps that answer on your device so Pro keeps working offline.</p>
        <p>To keep the free plan fair, the app counts how many scripts you have used. This small counter is stored on your device. So that it is not reset by deleting and reinstalling the app, a copy is kept in the iOS Keychain on iPhone and iPad, and in Android's backup of the app's settings. It contains script identifiers only, not their content.</p>
      </>
    ),
  },
  {
    id: "backup",
    title: "Backups",
    body: (
      <p>Your device may back up app data under its own settings, for example Android Auto Backup to your Google account, or iCloud and Time Machine on Apple devices. On Android, the app's settings and scripts folder are included in that backup so they can come back when you set up a new phone. Those backups are held by Apple or Google under their terms. You can switch them off in your device settings.</p>
    ),
  },
  {
    id: "sharing",
    title: "Who we share data with",
    body: (
      <>
        <p>We do not sell personal data and we do not share it for advertising. The only third parties involved are:</p>
        <ul>
          <li><b>Apple and Google</b>, for the app store, payments, and the speech and backup services described above.</li>
          <li><b>Sentry</b>, only if you turn on crash reports.</li>
        </ul>
        <p>If you use the share button on a script or a video, it goes to the app you choose, and that app's policy applies.</p>
      </>
    ),
  },
  {
    id: "rights",
    title: "Your rights and choices",
    body: (
      <>
        <p>Because we hold almost nothing about you, most choices are in your hands: delete a script or recording inside the app, or delete the app to remove its data from your device. You can withdraw any permission in your system settings and turn crash reports off in the app.</p>
        <p>If you are in the European Economic Area or the United Kingdom, you have the right to access, correct, delete, restrict or move the personal data we hold about you, and to object to its use. To use these rights, or to ask a question, write to <a href={`mailto:${email}`}>{email}</a>. You can also complain to your local data-protection authority, for example the Portuguese CNPD.</p>
      </>
    ),
  },
  {
    id: "children",
    title: "Children",
    body: (
      <p>TalkRoll is a general-purpose tool and is not directed at children under 13 (or under 16 where local law sets that age). We do not knowingly collect personal data from children.</p>
    ),
  },
  {
    id: "changes",
    title: "Changes to this policy",
    body: (
      <p>If we change what the app does with your data, we will update this page and the date above, and for material changes we will say so in the app or its release notes.</p>
    ),
  },
  {
    id: "contact",
    title: "Contact",
    body: (
      <p>Questions about privacy? Email <a href={`mailto:${email}`}>{email}</a>.</p>
    ),
  },
];

export default function PrivacyPage() {
  return (
    <LegalPage
      kicker="Privacy Policy"
      title={<>Your script <em>stays close.</em></>}
      summary="No account, no tracking, no uploads of your scripts. Here is exactly what TalkRoll does with your data."
      updated="7 November 2026"
      highlights={[
        { label: "Scripts", text: "Stored on your device only" },
        { label: "Account", text: "None needed" },
        { label: "Analytics", text: "None. Crash reports are opt-in" },
      ]}
      sections={sections}
      other={{ href: "/terms", label: "Terms of Use" }}
    />
  );
}
