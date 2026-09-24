# Admin Mode Design System — KREEN Judging

**Status:** Phase 4B.5 code/structure freeze candidate; visual freeze awaits manual screenshot sign-off. This extends, but does not overwrite, the frozen Judge Mode design system in `design-system.md`.

## Character

Admin Mode is premium, dark, calm, operational, and structured. It is intentionally more data-dense than Judge Mode, but must not become a white/blue SaaS dashboard, cyberpunk interface, gaming UI, or chart-heavy BI tool.

## Shared Visual Language

Admin uses the existing Judge palette. Because Safari's local-file policy rejects the Admin page's parent-directory resource request, `admin/admin.css` contains a deliberately small mirror of the same token values so `admin/*.html` remains portable through `file://`. This mirror must stay synchronized with `judge-prototype/assets/css/tokens.css`; it is not a new palette.

- Background/surfaces: burgundy-black `--bg-base`, `--surface`, `--surface-alt`, `--surface-raised`.
- Text: warm ivory `--text-primary`, muted warm gray `--text-secondary`.
- Accent: gold is reserved for active context, borders, labels, and restrained primary actions.
- Completion: solid green is reserved for strong completed states such as `Finalized`/`Submitted`.
- Error: warm coral is reserved for failures and destructive attention states.

## Layout

### Landscape / sufficiently wide screens

- Global navigation remains a left sidebar: 230–240px on desktop and about 208px on narrow landscape layouts.
- Main content is capped at 1600px, with 24–48px responsive side padding.
- Event Context and main content use the same centered max-width/padding contract; their text and content left edges must align at 1280, 1440, and 1920px.
- The sidebar is one shared rendering from `admin-navigation.js` + `admin-shell.js`; active state is a dark raised surface with a restrained gold edge, not a gold block.

### Portrait / narrow screens

- The global sidebar is replaced by a five-destination bottom bar: Home, Rounds, Live, Results, More.
- Bottom labels are 11px with touch targets at least 48px. The fixed bar must not cover the final page item/action: content reserves its height, safe-area inset, and extra breathing room. Drawers layer above the bar and keep their footer above the safe area.
- Each destination keeps both icon and text label. More opens a bottom sheet for Contestants, Judges, Settings, Audit Log, and Switch to Judge Mode.
- Results retains a primary slot despite being a placeholder: onsite results are a high-priority operational destination after judging closes; Contestants/Judges master-data configuration is less frequent and remains in More. Revisit when real usage data exists.
- The More sheet has at least 48px destination rows, explicit disabled states, a scrollable height cap, safe-area padding, and an explicit close button. Only the outside backdrop, close button, or Escape dismisses it; tapping empty space within the sheet does not.
- The breakpoint uses portrait orientation or a narrow viewport, not a device name. Landscape screens retain the sidebar.
- Round tabs remain a separate, single horizontal scroll row above page content; they never move into the global bottom bar.
- Round header compacts to Back → round name/status → contestant/judge facts; redundant Round Workspace labels are hidden in portrait. Each round page has one page title below the tabs.
- The active round tab is revealed automatically on page initialization and on viewport changes. Edge fades indicate additional tabs when horizontal overflow exists; no second navigation model is introduced.
- Data assignments use card-like rows and remain touch reachable. Full master data administration is optimized for tablet/desktop; mobile remains supported for light operational tasks, including reading and basic drawer edits.
- Content padding reserves space for the fixed bottom bar and the device safe area.
- Round tabs remain visible and persistent across round-level pages even when the page-specific content changes.

## Components

| Component | Rule |
|---|---|
| Sidebar item | Icon + text, min-height 46px, active uses subtle gold tint/border—not full gold fill. |
| Context bar | Shows static event name/year and current role in Phase 1; no complex selector logic. |
| Page header | Eyebrow, title, description, primary/secondary actions. |
| Round context | Round name/status/facts with horizontal tabs. |
| Status badge | Always text + dot; Draft muted gold, Open subtle green, Closed neutral, Finalized/Submitted solid green. |
| Stat card | Compact operational metric, not an oversized analytics tile. |
| Round card | Name/status, contestant/judge/criteria facts, submission progress, one clear action. |
| Data row | Landscape columns; portrait stacks metadata/action. More than two actions move to overflow pattern. |
| Form | Labels required; default/focus/error/disabled states; controls >=44px. |
| Toggle | Label and explanatory text accompany the switch; position alone is not meaning. |
| Modal | Explicit title and action copy for high-impact operations; never Yes/No. |
| Drawer | Right side on landscape, full/near-full width on portrait; Phase 1 is visual only. |
| Feedback | Small empty/error state and subtle skeleton loading; no large illustration/spinner. |

## Accessibility

- Interactive targets are 44px minimum; primary actions are 46px or more.
- Focus-visible outline uses the existing gold accent.
- Status never depends only on color.
- Inputs have labels; dialogs use `role="dialog"`, `aria-modal`, and labelled headings.

## Reference Implementation

## Admin Shell Contract

- Every Admin page MUST render through `admin/admin-shell.js` and `admin/admin-navigation.js`.
- Sidebar markup MUST NOT be duplicated in page HTML; active state is supplied through `data-active-nav`.
- Event Context MUST come from the shared renderer and keep the event name, year, and role treatment consistent.
- Every round-level page MUST use `admin/admin-round-workspace.js`; page content only fills the workspace slot.
- Round tabs use one shared order: Overview, Monitoring, Contestants, Judges, Criteria, Results, Settings.
- New Admin pages may supply page-specific content, dialogs, and interactions, but may not invent another shell or round context.

### Navigation hierarchy

- Global destinations and round tabs are distinct state: `globalActiveNav` belongs to the shell; `roundActiveTab` belongs to the selected round workspace.
- Every round-level page keeps global `Rounds` active. Only the round tab changes.
- Global `Live` is event-level operational control. A round-specific Monitoring view is reached only from a round's tabs and keeps global `Rounds` active.
- Event-level Contestants and Judges masters stay under their own global destinations; round Contestants/Judges tabs configure participation/assignment for the selected round.

### Renderer and persistence contract

- `renderRoundWorkspace({ roundId, activeTab, pageTitle, pageDescription, contentTarget })` owns the round context, tabs, and stable page-content slot. Page controllers fill only that slot.
- `getEffectiveScoredWeight(criteria)` is the sole effective-weight calculation. Non-scored parent groups do not contribute to weight.
- `getRoundReadiness(roundId)` derives readiness from current contestant assignments, judge assignments/required flags, criteria, and submission activity.
- Master records and round configuration use the versioned `kreenAdminConfiguration` localStorage namespace. The old master namespace is read only for migration; new edits write to the canonical namespace.

### Token parity

`admin.css` intentionally mirrors the shared token values in `../assets/css/tokens.css` so Safari can load Admin directly with `file://` and no parent-directory stylesheet dependency. Whenever a shared palette token changes, update both files in the same change and compare the `:root` token values. Do not introduce Admin-only colors for shared palette roles. This parity is documented rather than generated; there is no build tooling.

### Phase 4B.5 visual sign-off

Code/structure is ready for review, but visual freeze requires manual `file://` screenshots because the available browser automation cannot access local files. Compare Round Overview, Monitoring, and Criteria at 1440×900; Round Overview, Monitoring, and open More sheet at 800×1280; Rounds, Round Overview, and open More sheet at 430×932. Also inspect Admin Overview at 1920×1080, Round Contestants at 1280×800, and Criteria at 390×844. Check Event Context/content alignment, global vs round active navigation, tab visibility and edge affordance, one page title, portrait vertical density, bottom-bar safe spacing, More-sheet backdrop behavior, drawer footer visibility, and horizontal page overflow. Do not mark the visual foundation frozen until these screenshots are approved.

- `judge-prototype/admin/index.html` — Admin Shell/Overview layout reference.
- `judge-prototype/admin/rounds.html` — reusable round cards plus local empty/loading/error state references.
- `judge-prototype/admin/round.html?id=1` — round operational overview and readiness reference.
- `judge-prototype/admin/monitoring.html?round=1` — status-only judge monitoring reference.
- `judge-prototype/admin/design-system.html` — component preview page.
- `judge-prototype/admin/admin.css` — self-contained Admin styles and the portable token mirror.
- `judge-prototype/admin/admin-data.js` — shared structured local mock data and read helpers.
- `judge-prototype/admin/admin.js` — demo-only rendering/interaction wiring; no persistence or business logic.
