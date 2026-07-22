// Local government card — ward councillor + community committee for the address.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport } from "@/lib/report/types";

export function LocalGovernmentCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("localGovernment");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · Local government" title="Ward & councillor">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const gov = report.localGovernment;
  if (
    !gov ||
    (!gov.wardName &&
      !gov.councillor &&
      !gov.councillorPhone &&
      !gov.councillorWebsite &&
      !gov.communityCommittee)
  ) {
    return null;
  }

  return (
    <KrokvaCard
      eyebrow="Daily · Local government"
      title="Ward & councillor"
      subtitle={gov.wardName}
    >
      <Fact label="Ward" value={gov.wardName} />
      <Fact label="Councillor" value={gov.councillor} />
      <Fact label="Phone" value={gov.councillorPhone} />
      <Fact label="Website" value={gov.councillorWebsite} />
      <Fact label="Community committee" value={gov.communityCommittee} />
    </KrokvaCard>
  );
}
