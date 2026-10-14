"use client";

import { useLocale, useTranslations } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";

/// 言語の切り替え。既定が英語なので、日本語話者が辿り着ける入口が要る
export function LanguageSwitch() {
  const locale = useLocale();
  const t = useTranslations("language");
  const pathname = usePathname();

  return (
    <div className="flex items-center gap-0.5 rounded-full bg-white/8 p-0.5 text-[13px] ring-1 ring-white/10">
      {(["en", "ja"] as const).map((target) => (
        <Link
          className={`rounded-full px-3 py-1 font-semibold transition ${
            locale === target ? "bg-white/15 text-white" : "text-white/55 hover:text-white"
          }`}
          href={pathname}
          key={target}
          locale={target}
        >
          {t(target)}
        </Link>
      ))}
    </div>
  );
}
