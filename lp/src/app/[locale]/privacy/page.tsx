import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { languageAlternates, localePath, ogAlternateLocales, ogLocale } from "@/i18n/urls";

type Section = { title: string; body: string };

type PageProps = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "privacy" });

  return {
    title: t("title"),
    description: t("intro"),
    // 親の alternates ごと差し替わるので、hreflang もここで出し直す。
    // 書かないと /privacy から言語間の相互参照が消える
    alternates: {
      canonical: localePath(locale, "/privacy"),
      languages: languageAlternates("/privacy"),
    },
    // openGraph も親から丸ごと受け継ぐので、書かないと og:url がトップを指す
    openGraph: {
      alternateLocale: ogAlternateLocales(locale),
      description: t("intro"),
      locale: ogLocale(locale),
      title: t("title"),
      type: "website",
      url: localePath(locale, "/privacy"),
    },
  };
}

export default async function Page({ params }: PageProps) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("privacy");
  const sections = t.raw("sections") as Section[];

  return (
    <main className="px-6 py-16">
      <div className="mx-auto max-w-2xl">
        <h1 className="font-bold text-4xl tracking-[-0.02em]">{t("title")}</h1>
        <p className="mt-2 text-[var(--color-faint)] text-sm">{t("updated")}</p>
        <p className="mt-8 text-white/85 leading-relaxed">{t("intro")}</p>

        {sections.map((section) => (
          <section className="mt-10" key={section.title}>
            <h2 className="font-bold text-xl">{section.title}</h2>
            <p className="mt-3 text-[var(--color-mute)] leading-relaxed">{section.body}</p>
          </section>
        ))}

        <p className="mt-16 border-white/10 border-t pt-6 text-[var(--color-mute)] text-sm">
          <Link className="underline" href="/">
            ← {t("back")}
          </Link>
        </p>
      </div>
    </main>
  );
}
