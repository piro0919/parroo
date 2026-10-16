import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import type { ReactNode } from "react";
import { Link } from "@/i18n/navigation";
import { DesktopMock, StatusLines, Waves } from "./desktop-mock";
import { LanguageSwitch } from "./language-switch";

const REPO = "https://github.com/piro0919/parroo";
const DOWNLOAD = `${REPO}/releases/latest`;
const BREW = "brew install --cask piro0919/tap/parroo";

type Step = { title: string; body: string };

type PageProps = {
  params: Promise<{ locale: string }>;
};

/// 白い主ボタンと、縁だけの副ボタン。Sleeve の「Mac App Store」「Buy Directly」の対
function Buttons({ download, homebrew }: { download: string; homebrew: string }) {
  return (
    <div className="flex flex-wrap justify-center gap-3">
      <a
        className="inline-flex h-14 items-center rounded-full bg-white px-7 font-semibold text-[17px] text-black transition hover:bg-white/90"
        href={DOWNLOAD}
      >
        {download}
      </a>
      <a
        className="inline-flex h-14 items-center rounded-full px-7 font-semibold text-[17px] text-white ring-1 ring-white/20 transition hover:bg-white/5"
        href="#install"
      >
        {homebrew}
      </a>
    </div>
  );
}

/// 区画の見出し。色の付いた小さな札と、大きな1行
function SectionTitle({
  eyebrow,
  title,
  color,
}: {
  eyebrow: string;
  title: string;
  color: string;
}) {
  return (
    <div className="flex flex-col items-center gap-4 text-center">
      <span className={`eyebrow font-semibold text-[13px] ${color}`}>{eyebrow}</span>
      <h2 className="text-balance font-bold text-4xl tracking-[-0.02em] sm:text-5xl">{title}</h2>
    </div>
  );
}

function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`overflow-hidden rounded-[24px] bg-[var(--color-card)] ring-1 ring-[var(--color-card-line)] ${className}`}
    >
      {children}
    </div>
  );
}

function CardText({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex flex-col gap-3">
      <h3 className="font-semibold text-[22px] tracking-[-0.01em]">{title}</h3>
      <p className="text-[17px] text-[var(--color-mute)] leading-relaxed">{body}</p>
    </div>
  );
}

export default async function Page({ params }: PageProps) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations();
  const install = t.raw("install.steps") as Step[];

  // メニューバーに出せる組み合わせの見本。表記は CLAUDE.md の項目の表のとおり
  const variants = [
    ["1w: 69%", t("menu.statusDate")],
    ["5h: 42%", "5h: 1h 20m"],
    ["1w: 2d 5h", "5h: 16:30"],
    ["Opus: 30%", "Sonnet: 20%"],
    ["1w: 69%", "$12/$50"],
  ] as const;

  return (
    <div className="mx-auto max-w-[1200px] px-4 sm:px-10">
      {/* 上の帯 */}
      <header className="flex items-center justify-between py-8">
        <Link className="flex items-center gap-2.5" href="/">
          <Image alt="" className="h-8 w-8" height={64} src="/icon.png" width={64} />
          <span className="font-bold text-lg tracking-[-0.01em]">Parroo</span>
        </Link>
        <nav className="flex items-center gap-6 text-[15px] text-[var(--color-mute)]">
          <a className="hidden transition hover:text-white sm:inline" href={`${REPO}/releases`}>
            {t("footer.releases")}
          </a>
          <a className="hidden transition hover:text-white sm:inline" href={REPO}>
            GitHub
          </a>
          <LanguageSwitch />
        </nav>
      </header>

      {/* 見出し */}
      <section className="flex flex-col items-center pt-6">
        <div className="relative w-full max-w-[900px]">
          <DesktopMock />
          <Image
            alt=""
            className="-translate-x-1/2 absolute bottom-0 left-1/2 h-32 w-32 translate-y-1/2 drop-shadow-[0_20px_40px_rgba(0,0,0,0.6)] sm:h-44 sm:w-44"
            height={512}
            priority
            src="/icon-512.png"
            width={512}
          />
        </div>

        <div className="flex flex-col items-center gap-6 pt-28 text-center sm:pt-36">
          <h1 className="silver font-bold text-7xl tracking-[-0.04em] sm:text-[104px] sm:leading-none">
            Parroo
          </h1>
          <p className="text-balance font-bold text-3xl tracking-[-0.02em] sm:text-5xl">
            {t("hero.tagline")}
          </p>
          <p className="max-w-2xl text-pretty text-[19px] text-[var(--color-mute)] leading-relaxed sm:text-[21px]">
            {t("hero.lead")}
          </p>
          <div className="pt-4">
            <Buttons download={t("hero.download")} homebrew={t("hero.homebrew")} />
          </div>
          <p className="text-[14px] text-[var(--color-faint)]">{t("hero.requirement")}</p>
        </div>
      </section>

      {/* メニューバー */}
      <section className="flex flex-col gap-14 pt-40">
        <SectionTitle
          color="text-[var(--color-sprout)]"
          eyebrow={t("flow.eyebrow")}
          title={t("flow.title")}
        />

        <div className="wallpaper relative overflow-hidden rounded-[28px] ring-1 ring-white/10">
          <Waves id="variants" />
          <div className="relative flex flex-wrap items-center justify-center gap-4 px-6 py-20 sm:gap-6 sm:py-28">
            {variants.map(([first, second]) => (
              <div
                className="rounded-xl bg-black/35 px-4 py-2.5 ring-1 ring-white/10 backdrop-blur-md"
                key={`${first}-${second}`}
              >
                <StatusLines first={first} large second={second} />
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* できること */}
      <section className="flex flex-col gap-14 pt-40">
        <SectionTitle
          color="text-[var(--color-amber)]"
          eyebrow={t("features.eyebrow")}
          title={t("features.title")}
        />

        <div className="grid gap-6 md:grid-cols-2">
          <Card className="flex flex-col justify-between gap-10 p-9 md:col-span-2 md:flex-row md:items-center">
            <div className="md:max-w-[360px]">
              <CardText body={t("features.reset.body")} title={t("features.reset.title")} />
            </div>
            <div className="flex flex-col gap-1 md:text-right">
              <span className="whitespace-nowrap font-bold text-5xl tabular-nums tracking-[-0.03em]">
                {t("menu.resetDate")}
              </span>
              <span className="text-[17px] text-[var(--color-sprout)]">{t("menu.resetIn")}</span>
            </div>
          </Card>

          <Card className="flex flex-col gap-8 p-9">
            <CardText
              body={t("features.conversations.body")}
              title={t("features.conversations.title")}
            />
            <div className="flex flex-col gap-1 rounded-2xl bg-black/30 p-4 text-[14px]">
              <span className="font-semibold text-[12px] text-white/45">parroo</span>
              <div className="flex justify-between gap-4">
                <span className="truncate">{t("menu.conversationA")}</span>
                <span className="tabular-nums">182,431</span>
              </div>
              <div className="flex justify-between gap-4">
                <span className="truncate">{t("menu.conversationB")}</span>
                <span className="tabular-nums">3,108</span>
              </div>
            </div>
          </Card>

          <Card className="flex flex-col gap-8 p-9">
            <CardText body={t("features.stale.body")} title={t("features.stale.title")} />
            <span className="w-fit rounded-full bg-black/40 px-4 py-1.5 text-[15px] text-[var(--color-mute)] tabular-nums">
              {t("menu.updated")}
            </span>
          </Card>
        </div>
      </section>

      {/* 入れ方 */}
      <section className="flex scroll-mt-10 flex-col gap-14 pt-40" id="install">
        <SectionTitle
          color="text-[var(--color-sprout)]"
          eyebrow={t("install.eyebrow")}
          title={t("install.title")}
        />

        <div className="grid gap-6 md:grid-cols-2">
          {install.map((step, index) => (
            <Card className="flex flex-col gap-6 p-9" key={step.title}>
              <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-[var(--color-leaf)] font-bold text-lg tabular-nums">
                {index + 1}
              </span>
              <CardText body={step.body} title={step.title} />
            </Card>
          ))}
        </div>

        <pre className="mx-auto w-full max-w-xl overflow-x-auto rounded-2xl bg-[var(--color-card)] px-6 py-4 text-center font-mono text-[14px] text-white/85 ring-1 ring-[var(--color-card-line)]">
          <code>{BREW}</code>
        </pre>

        <div className="flex flex-col items-center gap-5 text-center">
          <Buttons download={t("install.cta")} homebrew={t("hero.homebrew")} />
          <p className="max-w-xl text-[14px] text-[var(--color-faint)] leading-relaxed">
            {t("install.note")}
          </p>
        </div>
      </section>

      {/* 下の帯 */}
      <footer className="mt-40 flex flex-col gap-6 border-white/10 border-t py-10 text-[14px] text-[var(--color-mute)] sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2.5">
          <Image alt="" className="h-6 w-6" height={64} src="/icon.png" width={64} />
          <span className="font-semibold text-white">Parroo</span>
        </div>
        <div className="flex flex-wrap gap-x-6 gap-y-2">
          <a className="transition hover:text-white" href={REPO}>
            {t("footer.source")}
          </a>
          <a className="transition hover:text-white" href={`${REPO}/releases`}>
            {t("footer.releases")}
          </a>
          <Link className="transition hover:text-white" href="/privacy">
            {t("footer.privacy")}
          </Link>
          <a className="transition hover:text-white" href="https://buymeacoffee.com/piro0919">
            Buy Me a Coffee
          </a>
        </div>
      </footer>
    </div>
  );
}
