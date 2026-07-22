// Amenities · Parks card — nearest park with amenity tallies, nearby parks,
// nearest off-leash dog park, and neighbourhood park count/hectares.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport, ParkAmenity } from "@/lib/report/types";

// The park-assets dataset has one row per asset component (each swing, slide or
// bench is its own record), so raw counts read as absurd ("62 playgrounds").
// Show which amenities the park HAS instead — that's what a buyer wants to know.
function amenityLine(park: ParkAmenity): string | undefined {
  const parts: string[] = [];
  if (park.playgrounds) parts.push("Playground");
  if (park.fields) parts.push("Sports fields");
  if (park.courts) parts.push("Courts");
  if (park.washrooms) parts.push("Washrooms");
  if (park.benches) parts.push("Benches");
  return parts.length ? parts.join(" · ") : undefined;
}

export function ParksCard({ report }: { report: AddressReport }) {
  const parks = report.parks;
  const failed = report.failedModules.includes("parks");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Parks" title="Parks & green space">
        <ErrorState />
      </KrokvaCard>
    );
  }

  if (
    !parks ||
    (!parks.nearestPark && !parks.nearestDogPark && parks.neighbourhoodParkCount === 0)
  ) {
    return null;
  }

  const nearby = parks.nearbyParks.slice(0, 8);
  const hectares =
    parks.neighbourhoodHectares != null
      ? `${parks.neighbourhoodHectares.toFixed(1)} ha`
      : undefined;

  return (
    <KrokvaCard
      eyebrow="Amenities · Parks"
      title="Parks & green space"
      subtitle="Within 500 m"
      accent={parks.nearbyParks.length ? `${parks.nearbyParks.length}` : undefined}
    >
      <Fact
        label="Nearest park"
        value={
          parks.nearestPark
            ? `${parks.nearestPark.name} · ${parks.nearestPark.distanceDescription}`
            : undefined
        }
      />
      <Fact
        label="Off-leash dog park"
        value={
          parks.nearestDogPark
            ? `${parks.nearestDogPark.name} · ${parks.nearestDogPark.distanceDescription}`
            : undefined
        }
      />
      <Fact
        label="Parks in neighbourhood"
        value={parks.neighbourhoodParkCount || undefined}
      />
      <Fact label="Green space" value={hectares} />

      {nearby.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Nearby parks</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
            {nearby.map((park) => {
              const amenities = amenityLine(park);
              return (
                <div
                  key={park.parkID}
                  style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                    <strong style={{ fontSize: 14 }}>{park.name}</strong>
                    <span className="card__subtitle">{park.distanceDescription}</span>
                  </div>
                  {amenities ? <div className="card__subtitle">{amenities}</div> : null}
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
