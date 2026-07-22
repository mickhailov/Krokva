// Map card — plots the subject address and nearby permits / vacant orders /
// planning notices. Server component; the Leaflet map itself is a client child.

import { KrokvaCard } from "../KrokvaCard";
import ReportMap, { MapPoint } from "../ReportMap";
import { AddressReport } from "@/lib/report/types";

export function MapCard({ report }: { report: AddressReport }) {
  const subject = report.property?.coordinate;
  if (!subject) return null;

  const points: MapPoint[] = [
    { lat: subject.latitude, lon: subject.longitude, title: report.property!.fullAddress, kind: "subject" },
  ];
  for (const p of report.permits) {
    if (p.coordinate) points.push({ lat: p.coordinate.latitude, lon: p.coordinate.longitude, title: `${p.type} — ${p.address}`, kind: "permit" });
  }
  for (const o of report.vacantOrders) {
    if (o.coordinate) points.push({ lat: o.coordinate.latitude, lon: o.coordinate.longitude, title: `Vacant order — ${o.address}`, kind: "vacant" });
  }
  for (const n of report.planning?.publicNotices ?? []) {
    if (n.coordinate) points.push({ lat: n.coordinate.latitude, lon: n.coordinate.longitude, title: `${n.noticeType} — ${n.address}`, kind: "notice" });
  }

  return (
    <KrokvaCard eyebrow="Report · Map" title="Location & nearby records" subtitle={report.property!.neighbourhood}>
      <ReportMap points={points} />
      <div style={{ display: "flex", gap: 14, flexWrap: "wrap", marginTop: 10, fontSize: 12, color: "var(--ink3)" }}>
        <Legend color="#B89455" label="This address" />
        {points.some((p) => p.kind === "permit") ? <Legend color="#2F7BFF" label="Permits" /> : null}
        {points.some((p) => p.kind === "vacant") ? <Legend color="#B07262" label="Vacant orders" /> : null}
        {points.some((p) => p.kind === "notice") ? <Legend color="#6B8166" label="Notices" /> : null}
      </div>
    </KrokvaCard>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
      <span style={{ width: 10, height: 10, borderRadius: 5, background: color, display: "inline-block" }} />
      {label}
    </span>
  );
}
