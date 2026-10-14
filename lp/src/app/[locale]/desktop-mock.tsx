import { getTranslations } from "next-intl/server";
import type { ReactNode } from "react";

/// Mac のデスクトップの見本。Sleeve の見出しの絵にならい、壁紙の上にメニューバーを置き、
/// Parroo のメニューを開いた状態で見せる。アプリの絵は常駐アイコンが埋まると撮れないので、
/// 画面写真ではなくここで組む。並びと文言はアプリのメニュー（Sources/main.swift）に合わせる
export async function DesktopMock() {
  const t = await getTranslations("menu");

  return (
    <div className="wallpaper relative h-[520px] w-full overflow-hidden rounded-[28px] ring-1 ring-white/10 sm:h-[560px]">
      <Waves id="hero" />

      {/* メニューバー */}
      <div className="relative flex h-7 items-center justify-between bg-black/25 px-4 text-[13px] text-white backdrop-blur-md">
        <div className="flex items-center gap-4">
          <AppleLogo />
          <span className="font-semibold">Finder</span>
        </div>
        <div className="flex items-center gap-3">
          <div className="rounded-[5px] bg-white/20 px-1.5 py-[3px]">
            <StatusLines first="1w: 69%" second={t("statusDate")} />
          </div>
          <span className="hidden tabular-nums sm:inline">{t("clock")}</span>
        </div>
      </div>

      {/* 開いたメニュー。常駐アイコンの真下から出す */}
      <div className="absolute top-9 right-3 w-[300px] max-w-[calc(100%-24px)] rounded-xl bg-[#232624]/80 p-1.5 text-[13px] text-white shadow-[0_24px_60px_-12px_rgba(0,0,0,0.7)] ring-1 ring-white/12 backdrop-blur-xl sm:right-[140px]">
        <Header>{t("week")}</Header>
        <Row>{t("used")}</Row>
        <Row>{t("weekReset")}</Row>
        <Header>{t("fiveHour")}</Header>
        <Row>{t("fiveUsed")}</Row>
        <Row>{t("fiveReset")}</Row>
        <Header>{t("models")}</Header>
        <Row>{t("model")}</Row>
        <Separator />
        <Header>parroo</Header>
        <Row tokens="182,431">{t("conversationA")}</Row>
        <Row tokens="3,108">{t("conversationB")}</Row>
        <Header>spatto</Header>
        <Row tokens="64,920">{t("conversationC")}</Row>
        <Separator />
        <Row muted>{t("updated")}</Row>
        <Row shortcut="⌘ ,">{t("settings")}</Row>
        <Row shortcut="⌘ Q">{t("quit")}</Row>
      </div>
    </div>
  );
}

/// メニューバーの2行表示。アプリと同じく左で揃える
export function StatusLines({
  first,
  second,
  large = false,
}: {
  first: string;
  second: string;
  large?: boolean;
}) {
  return (
    <div
      className={`flex flex-col font-medium text-white tabular-nums ${
        large ? "text-[13px] leading-[15px]" : "text-[9.5px] leading-[10.5px]"
      }`}
    >
      <span>{first}</span>
      <span>{second}</span>
    </div>
  );
}

/// 壁紙の波。Sleeve の見出しの絵にある、下から立ち上がる明るい波。
/// 1ページに2つ置くので、塗りの id は呼ぶ側で分ける
export function Waves({ id }: { id: string }) {
  return (
    <svg
      aria-hidden="true"
      className="absolute inset-x-0 bottom-0 h-[62%] w-full"
      preserveAspectRatio="none"
      viewBox="0 0 900 340"
    >
      <defs>
        <linearGradient id={`${id}-wave-a`} x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stopColor="#3ccb7f" />
          <stop offset="1" stopColor="#17a463" />
        </linearGradient>
        <linearGradient id={`${id}-wave-b`} x1="0" x2="1" y1="0" y2="0">
          <stop offset="0" stopColor="#0f6a4f" />
          <stop offset="1" stopColor="#0b4a3a" />
        </linearGradient>
      </defs>
      <path
        d="M0 80 C 180 40, 300 60, 420 170 S 700 330, 900 330 L 900 340 L 0 340 Z"
        fill={`url(#${id}-wave-b)`}
      />
      <path
        d="M0 170 C 160 120, 300 150, 430 240 S 720 330, 900 336 L 900 340 L 0 340 Z"
        fill={`url(#${id}-wave-a)`}
        opacity="0.9"
      />
    </svg>
  );
}

function AppleLogo() {
  return (
    <svg aria-hidden="true" className="h-[14px] w-[14px] fill-white" viewBox="0 0 24 24">
      <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
    </svg>
  );
}

function Header({ children }: { children: ReactNode }) {
  return (
    <div className="px-2.5 pt-1.5 pb-0.5 font-semibold text-[11px] text-white/45">{children}</div>
  );
}

function Row({
  children,
  tokens,
  shortcut,
  muted = false,
}: {
  children: ReactNode;
  tokens?: string;
  shortcut?: string;
  muted?: boolean;
}) {
  return (
    <div
      className={`flex items-baseline justify-between gap-4 rounded-md px-2.5 py-[3px] ${muted ? "text-white/45" : ""}`}
    >
      <span className="truncate">{children}</span>
      {tokens && <span className="shrink-0 tabular-nums">{tokens}</span>}
      {shortcut && <span className="shrink-0 text-white/45">{shortcut}</span>}
    </div>
  );
}

function Separator() {
  return <div className="mx-2.5 my-1 h-px bg-white/12" />;
}
