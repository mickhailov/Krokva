// Daily living — waste & winter: garbage/recycling/yard-waste collection days,
// plow zone + next plow window, and any active snow-route parking ban.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function WasteCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("waste");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · Waste & winter" title="Waste & winter">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const waste = report.waste;
  if (!waste) return null;

  const ban = waste.activeSnowBan;
  const hasAny =
    waste.garbageDay != null ||
    waste.recycleDay != null ||
    waste.yardWasteDay != null ||
    waste.plowZone != null ||
    waste.nextPlowWindow != null ||
    ban != null;
  if (!hasAny) return null;

  return (
    <KrokvaCard
      eyebrow="Daily · Waste & winter"
      title="Waste & winter"
      subtitle={waste.matchedAddress ?? undefined}
    >
      <Fact label="Garbage day" value={waste.garbageDay} />
      <Fact label="Recycling day" value={waste.recycleDay} />
      <Fact label="Yard-waste day" value={waste.yardWasteDay} />
      <Fact label="Plow zone" value={waste.plowZone} />
      <Fact label="Next plow window" value={waste.nextPlowWindow} />
      {ban ? (
        <div
          style={{
            marginTop: 12,
            padding: "10px 12px",
            background: "var(--surface-alt)",
            borderRadius: 8,
            border: "1px solid var(--line-soft)",
          }}
        >
          <span className="eyebrow">Active snow-route parking ban</span>
          <div style={{ marginTop: 6, fontSize: 14 }}>{ban.description}</div>
          {ban.start != null || ban.end != null ? (
            <div className="card__subtitle" style={{ marginTop: 4 }}>
              {[shortDate(ban.start), shortDate(ban.end)].filter(Boolean).join(" – ")}
            </div>
          ) : null}
        </div>
      ) : null}
    </KrokvaCard>
  );
}
