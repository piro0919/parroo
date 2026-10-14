import Image from "next/image";
import { getTranslations } from "next-intl/server";

/// メニューバーと、押したときのメニューの見本。アプリの絵は常駐アイコンが埋まると撮れないので、
/// 画面写真ではなくここで組む。並びと文言はアプリのメニュー（Sources/main.swift）に合わせる
export async function MenuMock() {
  const t = await getTranslations("menu");

  return (
    <div className="w-full max-w-md overflow-hidden rounded-3xl bg-[#1e2421]/95 text-[13px] text-white shadow-[0_30px_70px_-20px_rgba(0,40,25,0.6)] ring-4 ring-white/30 backdrop-blur">
      {/* メニューバー */}
      <div className="flex items-center justify-end gap-2 bg-black/50 px-4 py-1.5">
        <Image alt="" className="h-[18px] w-[18px]" height={36} src="/status-icon.png" width={36} />
        <div className="flex flex-col font-medium text-[10px] leading-[11px] tabular-nums">
          <span>1w: 69%</span>
          <span>{t("statusDate")}</span>
        </div>
      </div>

      {/* メニュー */}
      <div className="flex flex-col px-2 py-2">
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

function Header({ children }: { children: string }) {
  return <div className="px-3 pt-2 pb-0.5 font-bold text-[11px] text-white/45">{children}</div>;
}

function Row({
  children,
  tokens,
  shortcut,
  muted = false,
}: {
  children: string;
  tokens?: string;
  shortcut?: string;
  muted?: boolean;
}) {
  return (
    <div
      className={`flex items-baseline justify-between gap-6 rounded-md px-3 py-[3px] ${muted ? "text-white/45" : ""}`}
    >
      <span>{children}</span>
      {tokens && <span className="tabular-nums">{tokens}</span>}
      {shortcut && <span className="text-white/45">{shortcut}</span>}
    </div>
  );
}

function Separator() {
  return <div className="mx-3 my-1.5 h-px bg-white/15" />;
}
