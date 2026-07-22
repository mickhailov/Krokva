// Amenities — nearest public library, mirroring the app's LibraryAmenity card.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport } from "@/lib/report/types";

export function LibraryCard({ report }: { report: AddressReport }) {
  const library = report.library;
  const failed = report.failedModules.includes("library");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Library" title="Nearest library">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!library) return null;

  const features: string[] = [];
  if (library.wifi) features.push("Public Wi-Fi");
  if (library.accessibility) features.push("Accessible");
  if (library.roomRentals) features.push("Room rentals");
  if (library.parkingLot) {
    features.push(
      library.parkingStalls != null ? `Parking (${library.parkingStalls} stalls)` : "Parking lot",
    );
  }

  return (
    <KrokvaCard
      eyebrow="Amenities · Library"
      title={library.name}
      subtitle={library.distanceDescription}
      accent={library.distanceDescription}
      collapsible
      collapsedSummary={`${library.distanceDescription} away`}
    >
      <Fact label="Address" value={library.address} />
      {features.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Facilities</span>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 8 }}>
            {features.map((f) => (
              <span className="pill" key={f}>
                {f}
              </span>
            ))}
          </div>
        </div>
      ) : null}
      {library.notes ? (
        <p className="card__subtitle" style={{ marginTop: 12 }}>
          {library.notes}
        </p>
      ) : null}
      {!library.address && !features.length && !library.notes ? <EmptyState /> : null}
    </KrokvaCard>
  );
}
