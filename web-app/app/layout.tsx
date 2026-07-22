import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Krokva — the foundation of every address",
  description:
    "Krokva builds a clear civic dossier for any Winnipeg address — assessment, permits, safety, amenities and more, from municipal open data.",
  metadataBase: new URL("https://krokva.com"),
  openGraph: {
    title: "Krokva",
    description: "The foundation of every address. Civic address dossiers.",
    type: "website",
    siteName: "Krokva",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
