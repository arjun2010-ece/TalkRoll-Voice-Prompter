import type { Metadata } from "next";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim().replace(/\/+$/, "");

export const metadata: Metadata = {
  metadataBase: siteUrl ? new URL(siteUrl) : undefined,
  title: {
    default: "TalkRoll — Best Teleprompter App That Follows Your Voice",
    template: "%s | TalkRoll",
  },
  description:
    "The best teleprompter app for every script. Voice-activated scrolling that follows your words, auto-scroll, and narration sync on Mac, iPhone, iPad, and Android. Record video, retake sections, free to try.",
  applicationName: "TalkRoll",
  keywords: [
    "best teleprompter app",
    "teleprompter app",
    "voice-activated teleprompter",
    "voice scrolling teleprompter",
    "teleprompter that follows your voice",
    "teleprompter for iPhone",
    "teleprompter for iPad",
    "teleprompter for Android",
    "teleprompter for Mac",
    "free teleprompter app",
    "video teleprompter app",
    "teleprompter for Zoom",
    "script reader",
    "floating teleprompter",
    "mirror teleprompter text",
  ],

  authors: [{ name: "Arjun Sah" }],
  creator: "Arjun Sah",
  publisher: "TalkRoll",
  category: "Productivity",
  alternates: siteUrl ? { canonical: "/" } : undefined,
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    title: "TalkRoll — Best Teleprompter App That Follows Your Voice",
    description:
      "Voice-activated scrolling, auto-scroll, and narration sync on Mac, iPhone, iPad, and Android. Record video and retake sections.",
    siteName: "TalkRoll",
    url: siteUrl,
  },
  twitter: {
    card: "summary",
    title: "TalkRoll — Best Teleprompter App That Follows Your Voice",
    description:
      "The best teleprompter app: it follows your voice on Mac, iPhone, iPad, and Android.",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
