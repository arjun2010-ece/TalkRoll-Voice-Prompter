import type { Metadata } from "next";
import LegalPage, { type LegalSection } from "../../components/LegalPage";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "The terms for using EchoPrompter, including the free plan, EchoPrompter Pro and how subscriptions work.",
  alternates: { canonical: "/terms" },
};

const email = "arjun@echoprompter.app";

const sections: LegalSection[] = [
  {
    id: "agreement",
    title: "Agreement",
    body: (
      <p>These terms are an agreement between you and Arjun Sah (“we”, “us”), the maker of EchoPrompter, for the EchoPrompter apps on macOS, iPhone, iPad and Android and the website at echoprompter.app. By installing or using EchoPrompter you accept them. If you do not agree, please do not use the app. Your use of the App Store or Google Play is also subject to their own terms, and for apps from the App Store Apple's standard Licensed Application End User License Agreement applies alongside these terms.</p>
    ),
  },
  {
    id: "licence",
    title: "Your licence",
    body: (
      <>
        <p>We give you a personal, non-exclusive, non-transferable licence to install and use EchoPrompter on your own devices, for your own work, including professional work such as presentations and videos you make.</p>
        <p>You may not copy, resell, sublicense, reverse engineer or remove the protections of the app, except where the law allows it regardless of this clause, or use it to build a competing product from our code or design.</p>
      </>
    ),
  },
  {
    id: "content",
    title: "Your scripts and recordings",
    body: (
      <p>Your scripts, notes, narration recordings and videos belong to you. We do not claim any right to them and we do not upload them (see the <a href="/privacy">Privacy Policy</a>). You are responsible for having the right to use any text or audio you put into the app, and for what you record and publish with it.</p>
    ),
  },
  {
    id: "plans",
    title: "Free plan and EchoPrompter Pro",
    body: (
      <>
        <p>EchoPrompter is free to use within the limits of the free plan. Every feature is available on the free plan, and the limits are on how much you use it, such as how many scripts you can save and present. The current limits are shown in the app. Your existing scripts always stay readable, copyable and deletable, even when a limit is reached.</p>
        <p>EchoPrompter Pro removes those limits. Pro is offered as a monthly subscription, a yearly subscription and a one-time lifetime purchase. The price and billing period for each are shown in the app, in your store's currency, before you buy.</p>
      </>
    ),
  },
  {
    id: "billing",
    title: "Payments, renewal and refunds",
    body: (
      <>
        <ul>
          <li>Payment is taken by Apple or Google when you confirm the purchase, and is charged to your store account.</li>
          <li><b>Subscriptions renew automatically</b> at the end of each period (monthly or yearly) at the price shown, until you cancel. Cancel at least 24 hours before the end of the current period in your store's subscription settings. Deleting the app does not cancel a subscription.</li>
          <li>The lifetime purchase is a single payment that unlocks Pro for as long as the app is offered, on the devices tied to your store account.</li>
          <li><b>Restore Purchases</b> in the app brings Pro back on a new device or after a reinstall, using the same store account.</li>
          <li>Refunds and billing problems are handled by Apple or Google under their policies; we cannot issue refunds ourselves for store purchases.</li>
          <li>We may change prices for future purchases or renewals. Subscribers are told in the way the store requires before a price change takes effect.</li>
        </ul>
      </>
    ),
  },
  {
    id: "acceptable",
    title: "Acceptable use",
    body: (
      <p>Do not use EchoPrompter to break the law, to infringe other people's rights, or to record anyone without the consent the law requires where you are. The “hide from screen capture” option is meant to keep your own notes private during calls and recordings. It is not a way to deceive others about what is on your screen, and it may not work in every app or on every system.</p>
    ),
  },
  {
    id: "permissions",
    title: "Device permissions and accuracy",
    body: (
      <p>Features such as following your voice or a recording depend on speech recognition provided by your device. Recognition can be wrong or slow, especially with background noise, strong accents, or languages your device does not support well. EchoPrompter does its best to keep up, but we cannot promise it will follow every word. Please rehearse before an important presentation or recording and keep a way to scroll by hand.</p>
    ),
  },
  {
    id: "updates",
    title: "Updates and changes to the app",
    body: (
      <p>We may update, change or remove features, and we may update the app to keep it working with new operating systems. Some updates may be needed for the app to keep working. We may also change these terms; if we do, the updated terms will be published here with a new date, and the changes apply from the date shown. If you keep using the app after that, you accept the new terms.</p>
    ),
  },
  {
    id: "warranty",
    title: "No warranty",
    body: (
      <p>EchoPrompter is provided “as is” and “as available”. To the extent the law allows, we do not promise that it will be error-free, uninterrupted or fit for a particular purpose. Nothing in these terms limits rights you have as a consumer under the law where you live that cannot be excluded by contract.</p>
    ),
  },
  {
    id: "liability",
    title: "Limit of liability",
    body: (
      <p>To the extent the law allows, we are not liable for indirect or consequential losses, such as lost opportunities, lost recordings or a missed presentation, and our total liability to you for anything arising from the app is limited to the amount you paid us for it in the 12 months before the claim. This does not limit liability that cannot be limited by law, such as for death or personal injury caused by negligence, or for fraud.</p>
    ),
  },
  {
    id: "ending",
    title: "Ending these terms",
    body: (
      <p>You can stop using EchoPrompter at any time by deleting the app. We may suspend or end your access if you seriously or repeatedly break these terms. Sections that by their nature should survive, such as the limits on liability, continue after that.</p>
    ),
  },
  {
    id: "law",
    title: "Governing law",
    body: (
      <p>These terms are governed by the laws of Portugal, and the courts of Portugal have jurisdiction, except that if you are a consumer you keep any mandatory protections and the right to bring a claim in the courts of the country where you live.</p>
    ),
  },
  {
    id: "contact",
    title: "Contact",
    body: (
      <p>Questions about these terms? Email <a href={`mailto:${email}`}>{email}</a>.</p>
    ),
  },
];

export default function TermsPage() {
  return (
    <LegalPage
      kicker="Terms of Use"
      title={<>Simple terms, <em>fairly written.</em></>}
      summary="What you can expect from EchoPrompter, and what we ask of you. Plain language, with the subscription details up front."
      updated="7 November 2026"
      highlights={[
        { label: "Your content", text: "Always yours" },
        { label: "Free plan", text: "Every feature, with usage limits" },
        { label: "Pro", text: "Billed by Apple or Google; cancel any time" },
      ]}
      sections={sections}
      other={{ href: "/privacy", label: "Privacy Policy" }}
    />
  );
}
