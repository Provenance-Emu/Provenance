# Shared home screen widgets package (PVWidgets)

Date: 2026-11-19. Status: package 0.1.0 tagged; Provenance switched; iCube and iFly pending.

## Why

Provenance's Recently Played and Favorites widgets clip covers and titles on some
screens. Each grid picks a fixed game count per widget family and draws every cover
as a square as wide as its cell; nothing ties the grid's height to the widget's
height, so on an iPad (where the same family has a different shape) rows run past
the bottom. iCube copied the code and clips for a related reason (fixed 3:4 covers
with no height limit). iFly avoids it with a list that tries row counts until one
fits. Three apps, three copies, three behaviours.

## Goals

- One Swift package draws the game feed widgets for Provenance, iCube and iFly.
- Nothing clips at any widget size on any device: the layout comes from the
  widget's real size.
- The person can pick the layout (Automatic, Grid, List) and the feed (recents,
  favorites, continues and whatever else the app supplies) from the widget's edit
  screen.
- Each app keeps its own stored data and its own look.

## Non-goals

- Lock Screen, StandBy, Live Activity, Control Center and stats widgets stay in each app.
- No change to any app's stored widget data format.
- Not merged into PVLibrarySnapshot, and no app is moved onto its data model.

## Approaches considered

1. **New package with an app-neutral item and per-app adapters (picked).** Each app
   maps its own data into `WidgetItem` through a `WidgetDataSource`. No stored data
   changes, and the three apps adopt it independently.
2. Put the views in PVLibrarySnapshot and move all three apps onto its model.
   Forces a data change in Provenance and iFly, and its type names collide with
   Provenance's `PVLibrarySnapshotLegacy`.
3. Fix each app's layout in place. Quickest, leaves three copies.

Owner picked 1 on 2026-11-19.

## Design

Repo: `Provenance-Emu/PVWidgets`, consumed by URL and version tag.

Two targets:

- `PVWidgetsLayout`: Foundation only. `WidgetLayoutEngine.plan(...)` takes the
  content size, the style and the item count and returns a `WidgetLayoutPlan`:
  `.hero`, `.grid(columns, rows, cell size, title lines, meta line)` or
  `.list(columns, rows, row height)`. Pure, so it is unit tested against real
  iPhone and iPad widget sizes. The plan always fills the content rect exactly:
  the cell height is the space divided by the row count, and the cover gets what
  is left after a reserved title block. Font sizes are fixed points so the
  reserved block is exact.
- `PVWidgets`: SwiftUI, WidgetKit, AppIntents.
  - `WidgetItem`: id, title, subtitle, badge, artwork file URL, date, launch URL.
  - `WidgetFeed`: id, title, SF Symbol, empty message. Well-known ids for recents,
    favorites, continues, recently added and continue elsewhere; apps may add more.
  - `WidgetDataSource`: the feeds an app supplies and the items of a feed.
  - `WidgetTheme`: background, cell, badge, text styles and font design.
  - `PVWidgetsHost.configure(dataSource:theme:)`: called once from the app's
    `WidgetBundle.init`.
  - `FeedWidgetIntent`: Show (a feed entity whose choices come from the data
    source) and Layout. No feed chosen means the widget's own default, which is
    how one intent serves a Recently Played widget and a Favorites widget.
  - `FeedWidgetProvider` plans from `context.displaySize`, loads only the covers
    the plan shows, and decodes each to the pixel size it is drawn at (ImageIO
    thumbnails, as `CGImage`). One entry per timeline.
  - `FeedWidgetView` draws a plan. Covers are fitted, never cropped, in grids and
    lists; the single-game hero tile fills.

Layout rules (builder's call):

- Small family or one item: hero.
- Automatic: grid.
- Grid: among column and row counts whose cells meet the minimum width and cover
  height, show the most items, then prefer the cover shape closest to the theme's
  preferred shape, then the fewest empty slots.
- List: the tallest row height that still shows every item, else the shortest;
  two columns when the widget is wide (extra large).

## Adoption

- Provenance: Recently Played and Favorites keep their `kind` strings and move
  from `StaticConfiguration` to `AppIntentConfiguration`, so widgets already on a
  Home Screen stay. The adapter reads the existing `widget.*` app group keys.
  Feeds on day one: recents, favorites and recently added (the app already wrote
  `widget.recentlyAddedGames`). Continues need the app to write save states first.
- iCube and iFly: separate sessions, after the first tag.

## Left to the builder

Exact spacing constants, the header's look, test device sizes.

## Not verified by design

The static-to-intent switch keeping placed widgets needs a device check.
