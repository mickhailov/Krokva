# Krokva · Editorial — SwiftUI handoff

A drop-in SwiftUI port of the Editorial direction:

- Cream "paper" base with dusty muted accents (slate · ochre · sage · clay)
- iOS liquid-glass tiles — translucent, blurred, hairline-bordered, depth-shadowed
- Apple-blue accent + halo glow for interaction and "best" states
- Editorial display type — heavy condensed caps

---

## Files

| File | What it gives you |
|---|---|
| `Branding+Editorial.swift`  | Color palette (`Color.krokvaEd*`), typography (`KrokvaEdTypography`), `.krokvaEdEyebrow()`, `.krokvaEdTitle()` modifiers |
| `GlassSurfaces.swift`       | `KrokvaEdAmbient` (background blob wash), `KrokvaGlassCard` + `.krokvaEdGlass(tint:)`, `KrokvaEdBluePill`, `.krokvaEdBlueGlow()` |
| `StackedRows.swift`         | `KrokvaEdStackRow` (pill row with glyph + label + arrow), `KrokvaEdFeaturedRow` (the larger featured card) |
| `HeroPropertyCard+Editorial.swift` | `KrokvaEdHeroAddress`, `KrokvaEdValueTile`, `KrokvaEdMiniTile`, `EdTag` |
| `CompareView.swift`         | `KrokvaEdCompareView` + `KrokvaEdCompareProperty` model — 2–3 property side-by-side comparison |
| `HomeView+Editorial.swift`  | `KrokvaEdHomeView` — complete example screen wiring everything together |

All new types are namespaced `KrokvaEd*` / `krokvaEd*` so they coexist with the existing Civic Modernist `Branding.swift` without breaking anything.

---

## How to apply

1. Drag the entire `Editorial/` folder into your Xcode project (Copy items if needed).
2. **⌘B** to build — should compile clean with no changes to other files.
3. Where you currently push your Search/Home screen, swap to `KrokvaEdHomeView()` (or pull pieces of it into your existing view).
4. The other components (`KrokvaEdHeroAddress`, `KrokvaEdValueTile`, etc.) drop into your existing Dossier layout — they're styled to slot into a `LazyVStack(spacing: 14)` inside a `ZStack { Color.krokvaEdPaper; KrokvaEdAmbient(); ScrollView { ... } }`.

---

## Required pattern for every Editorial screen

Liquid glass needs something to refract — wrap each screen like this:

```swift
ZStack {
    Color.krokvaEdPaper.ignoresSafeArea()
    KrokvaEdAmbient()             // colored blob wash, sits behind everything
    ScrollView {
        // your content with .krokvaEdGlass(tint:) tiles
    }
}
```

Without `KrokvaEdAmbient`, the glass tiles will read as flat translucent panels rather than depth-rich glass.

---

## Tinted glass quick-ref

| Variant | Call |
|---|---|
| Clear glass (default) | `.krokvaEdGlass()` |
| Slate (cool navy)     | `.krokvaEdGlass(tint: .krokvaEdSlate, contentColor: .white)` |
| Ochre (warm gold)     | `.krokvaEdGlass(tint: .krokvaEdOchre, contentColor: .krokvaEdOnOchre)` |
| Sage (muted green)    | `.krokvaEdGlass(tint: .krokvaEdSage, contentColor: .krokvaEdOnSage)` |
| Clay (terracotta)     | `.krokvaEdGlass(tint: .krokvaEdClay, contentColor: .white)` |
| Ink (dark slate)      | `.krokvaEdGlass(tint: .krokvaEdInk, tintOpacity: 0.82, contentColor: .white)` |

Default `tintOpacity` is `0.78`. Lower it (~0.55) for cream/white tiles so more of the ambient color bleeds through.

---

## Compare view — example usage

```swift
let props = [
    KrokvaEdCompareProperty(
        id: "A", address: "412 Wellington", area: "Crescentwood",
        label: "Pinned", assessed: 1247, assessedLabel: "$1.247M",
        delta: "+5.4%", sf: 3420, lot: 8250, year: 1924,
        era: "Pre-war", permits: 3, rooms: "4bd · 3.5ba",
        tint: .krokvaEdSlate, foreground: .white
    ),
    // ... B, C ...
]

KrokvaEdCompareView(
    properties: props,
    recommendationTitle: "718 Mulvey\nstrongest on size & growth.",
    recommendationBody: "Largest interior + lot, highest YoY growth..."
)
```

---

## Optional: bundled display font

The display titles fall back to `Font.system(...).width(.condensed).weight(.heavy)` if no custom font is bundled, which already looks editorial enough on iOS 17+. To match the HTML mockups exactly, add **Archivo Black** to your `Info.plist` under `UIAppFonts` and ship `ArchivoBlack-Regular.ttf` in your bundle — the typography enum auto-detects it.

---

## Caveats

- iOS 16+ required for `Font.Width.condensed` and `.ultraThinMaterial` everywhere.
- `KrokvaEdAmbient` uses 4 blurred circles — cheap, but if you scroll a very long screen and notice jank, hoist it above the `ScrollView` (it already is in the example) so it doesn't re-layout per scroll.
- The blue glow shadows are intentionally large — on a dense screen with many "best" cells, consider toggling them off with `glow: false` on `KrokvaEdBluePill` so they don't compound.
