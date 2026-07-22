// By-Law investigations card — neighbourhood complaint activity by year and the
// top complaint types over the last year.

import { EmptyState, ErrorState, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend, HBars } from "../viz/Viz";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function BylawCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("bylaw");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · By-law" title="By-law investigations">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const bylaw = report.bylaw;
  if (!bylaw || (bylaw.yearly.length === 0 && bylaw.complaintTypes.length === 0)) return null;

  const yearly = [...bylaw.yearly].sort((a, b) => a.year - b.year);
  const lastYear = yearly.length ? yearly[yearly.length - 1].count : undefined;

  return (
    <KrokvaCard
      eyebrow="Permits · By-law"
      title="By-law investigations"
      subtitle={`${bylaw.neighbourhood} · complaints per year`}
      accent={lastYear != null ? `${lastYear}` : undefined}
    >
      {yearly.length ? (
        <ColumnTrend
          items={yearly.map((y) => ({
            label: `${y.year}`,
            value: y.count,
            context: y.citywideAverage > 0 ? y.citywideAverage : undefined,
          }))}
          contextLabel="city-wide neighbourhood average"
        />
      ) : null}

      {bylaw.complaintTypes.length ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Top complaint types</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={bylaw.complaintTypes.slice(0, 7).map((t) => ({
                label: titleCase(t.incidentType) ?? t.incidentType,
                value: t.count,
                context: t.citywideAverage > 0 ? t.citywideAverage : undefined,
              }))}
            />
          </div>
        </div>
      ) : null}

      {yearly.length === 0 && bylaw.complaintTypes.length === 0 ? <EmptyState /> : null}
    </KrokvaCard>
  );
}
