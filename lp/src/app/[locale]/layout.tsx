import { Analytics } from "@vercel/analytics/next";
import type { Metadata } from "next";
import { Noto_Sans_JP } from "next/font/google";
import { notFound } from "next/navigation";
import { hasLocale, NextIntlClientProvider } from "next-intl";
import { getTranslations, setRequestLocale } from "next-intl/server";
import type { ReactNode } from "react";
import { routing } from "@/i18n/routing";
import { languageAlternates, localePath, ogAlternateLocales, ogLocale } from "@/i18n/urls";
import "./globals.css";

// Mac では SF Pro とヒラギノで出すので、これはそれ以外の端末の日本語の受け皿。
// 日本語の書体は unicode-range で100件以上に割られていて、先読みすると
// 1ページで1.5MB読む。preload を切って、使う字の分だけ取らせる
const noto = Noto_Sans_JP({
  display: "swap",
  preload: false,
  variable: "--font-noto",
  weight: ["400", "500", "600", "700"],
});

type LayoutProps = {
  children: ReactNode;
  params: Promise<{ locale: string }>;
};

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: Omit<LayoutProps, "children">): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "meta" });

  return {
    description: t("description"),
    alternates: {
      canonical: localePath(locale),
      languages: languageAlternates(),
    },
    metadataBase: new URL("https://parroo.kkweb.io"),
    openGraph: {
      locale: ogLocale(locale),
      alternateLocale: ogAlternateLocales(locale),
      description: t("description"),
      url: localePath(locale),
      title: t("title"),
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      description: t("description"),
      title: t("title"),
    },
    title: t("title"),
  };
}

export default async function Layout({ children, params }: LayoutProps) {
  const { locale } = await params;

  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }
  setRequestLocale(locale);

  return (
    <html className={noto.variable} lang={locale}>
      <body className="font-system antialiased">
        <NextIntlClientProvider>{children}</NextIntlClientProvider>
        <Analytics />
      </body>
    </html>
  );
}
