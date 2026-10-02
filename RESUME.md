# Krokva — on hold (archived 2026-10-02)

Project is paused. Everything is pushed to GitHub: `git@github.com:mickhailov/Krokva.git`.

## Picking it back up
1. Copy this folder back to `~/Documents/Krokva` (same path → Claude Code memory reconnects),
   or `git clone git@github.com:mickhailov/Krokva.git ~/Documents/Krokva`.
2. iOS app: `xcodegen generate`, then build the `Krokva` scheme in Xcode.
3. Web app: `cd web-app && npm install && npm run dev`.

## Open work
- Branch `claude/homepage-report-example-7aa86a` — unfinished landing-page redesign
  (`web-app/app/page.tsx`, `globals.css`, `report/loading.tsx`, `components/AddressForm.tsx`). Not merged.
- Data backend: CDS facade `civic.144.217.5.174.sslip.io` — check it's still up before debugging "Database error".
