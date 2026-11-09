import type { ReactNode } from "react";

export type LegalSection = { id: string; title: string; body: ReactNode };

type Props = {
  kicker: string;
  title: ReactNode;
  summary: string;
  updated: string;
  highlights?: { label: string; text: string }[];
  sections: LegalSection[];
  other: { href: string; label: string };
};

// Shared layout for the Privacy Policy and the Terms of Use. Server Component: no client JS needed.
export default function LegalPage({ kicker, title, summary, updated, highlights, sections, other }: Props) {
  return (
    <main className="legal">
      <header className="legal-hero">
        <nav className="nav shell" aria-label="Primary navigation">
          <a className="brand" href="/" aria-label="TalkRoll home">
            <span className="brand-mark" aria-hidden="true"><img src="/icon.png" alt="" /></span>
            <span>TalkRoll</span>
          </a>
          <div className="nav-links">
            <a href="/privacy">Privacy</a>
            <a href="/terms">Terms</a>
          </div>
          <a className="nav-cta" href="/">Back to site <span aria-hidden="true">↗</span></a>
        </nav>
        <div className="shell legal-hero-copy">
          <p className="kicker"><span /> {kicker}</p>
          <h1>{title}</h1>
          <p className="legal-summary">{summary}</p>
          <p className="legal-updated">Last updated {updated}</p>
        </div>
      </header>

      <div className="shell legal-layout">
        <aside className="legal-toc" aria-label="On this page">
          <p className="section-label">On this page</p>
          <ol>
            {sections.map((s) => (
              <li key={s.id}><a href={`#${s.id}`}>{s.title}</a></li>
            ))}
          </ol>
        </aside>

        <article className="legal-body">
          {highlights && (
            <div className="legal-highlights">
              {highlights.map((h) => (
                <div key={h.label}><b>{h.label}</b><span>{h.text}</span></div>
              ))}
            </div>
          )}
          {sections.map((s, i) => (
            <section key={s.id} id={s.id}>
              <h2><span>{String(i + 1).padStart(2, "0")}</span>{s.title}</h2>
              {s.body}
            </section>
          ))}
          <p className="legal-other">Also read our <a href={other.href}>{other.label}</a>.</p>
        </article>
      </div>

      <footer className="footer">
        <div className="shell footer-inner">
          <div className="footer-branding">
            <a className="brand" href="/"><span className="brand-mark" aria-hidden="true"><img src="/icon.png" alt="" /></span><span>TalkRoll</span></a>
            <p>Made in Portugal by Arjun Sah <span aria-hidden="true">·</span> © 2026 TalkRoll</p>
          </div>
          <nav className="footer-links" aria-label="Footer navigation">
            <a href="/">Home</a>
            <a href="/privacy">Privacy Policy</a>
            <a href="/terms">Terms of Use</a>
          </nav>
        </div>
      </footer>
    </main>
  );
}
