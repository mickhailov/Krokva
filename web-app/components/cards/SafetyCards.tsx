// Safety & health cards — WFPS emergency calls (more modules append here:
// public health, police crime, neighbourhood risk).

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { titleCase } from "@/lib/format";
import { EmergencySummary } from "@/lib/report/types";

export function EmergencyCard({
  emergency,
  failed,
}: {
  emergency?: EmergencySummary;
  failed: boolean;
}) {
  if (failed) {
    return (
      <KrokvaCard eyebrow="Safety · WFPS" title="Emergency calls">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!emergency || emergency.totalLastYear === 0) return null;
  const top = emergency.last12Months.slice(0, 6);
  return (
    <KrokvaCard
      eyebrow="Safety · WFPS"
      title="Emergency calls"
      subtitle={`${emergency.neighbourhood} · last 12 months`}
      accent={`${emergency.totalLastYear}`}
    >
      <Fact label="Total calls (last year)" value={emergency.totalLastYear} />
      <Fact
        label="Motor-vehicle incidents"
        value={emergency.motorVehicleLastYear || undefined}
      />
      <Fact
        label="Avg response duration"
        value={
          emergency.averageDurationMinutes != null
            ? `${Math.round(emergency.averageDurationMinutes)} min`
            : undefined
        }
      />
      {top.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Top call types</span>
          <div style={{ marginTop: 8 }}>
            {top.map((t) => (
              <div className="kv" key={t.incidentType}>
                <span className="kv__key">{titleCase(t.incidentType)}</span>
                <span className="kv__val">{t.count}</span>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
