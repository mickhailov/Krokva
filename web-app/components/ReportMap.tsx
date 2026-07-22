"use client";

// Interactive report map — subject address plus nearby permits, vacant-building
// orders and planning notices, mirroring the app's ReportMapCard. Uses plain
// Leaflet loaded on the client (dynamic import inside the effect keeps it out of
// the server bundle). OpenStreetMap tiles.

import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";

export interface MapPoint {
  lat: number;
  lon: number;
  title: string;
  kind: "subject" | "permit" | "vacant" | "notice";
}

const KIND_COLOR: Record<MapPoint["kind"], string> = {
  subject: "#B89455",
  permit: "#2F7BFF",
  vacant: "#B07262",
  notice: "#6B8166",
};

export default function ReportMap({ points }: { points: MapPoint[] }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let map: any;
    let cancelled = false;
    (async () => {
      const L = (await import("leaflet")).default;
      if (cancelled || !ref.current) return;

      const subject = points.find((p) => p.kind === "subject") ?? points[0];
      map = L.map(ref.current, { scrollWheelZoom: false, attributionControl: true });
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "© OpenStreetMap contributors",
      }).addTo(map);

      const latlngs: [number, number][] = [];
      for (const p of points) {
        const isSubject = p.kind === "subject";
        L.circleMarker([p.lat, p.lon], {
          radius: isSubject ? 9 : 6,
          color: "#ffffff",
          weight: isSubject ? 3 : 1.5,
          fillColor: KIND_COLOR[p.kind],
          fillOpacity: 1,
        })
          .addTo(map)
          .bindPopup(`<strong>${p.title}</strong>`);
        latlngs.push([p.lat, p.lon]);
      }

      if (latlngs.length > 1) {
        map.fitBounds(latlngs as any, { padding: [30, 30], maxZoom: 16 });
      } else if (subject) {
        map.setView([subject.lat, subject.lon], 15);
      }
    })();

    return () => {
      cancelled = true;
      if (map) map.remove();
    };
  }, [points]);

  return (
    <div
      ref={ref}
      style={{ height: 320, width: "100%", borderRadius: "var(--radius-sm)", overflow: "hidden", background: "var(--surface-alt)" }}
    />
  );
}
