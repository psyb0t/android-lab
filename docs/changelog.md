# Changelog

All notable Android lab releases are documented here.

## Unreleased

### Added

- Portable Android Lab skills and setup references, with README instructions for installing them in another Android project.

- Codeberg and GitLab mirrors, scheduled mirror issue sync, and public archive jobs.

### Changed

- The README documents generic port forwarding without launcher-specific protocols.
- Make sizes tool CPU limits and Gradle workers for the Docker host, capped at ten CPUs.

- Split Dikciz Launcher into a standalone repository. Android Lab now embeds generic Gradle, emulator and device commands in local versioned tooling images.
- Consumers build Android Lab images locally, then use their own Makefiles. Images are not published to a registry.
- Gradle projects may live at the consumer workspace root. Controllers use explicit host workspace paths and workspace-specific Compose names.

### Fixed

- Lab contract tests check the configured Gradle worker count instead of requiring ten workers on every runner.

### Migration

- Build both images with `make build` in Android Lab after SDK license acceptance, then run Dikciz operations from its separate checkout.
- Preserve `.android-lab/` when migrating. It contains the saved phone and stable signing identity.
- Earlier entries below describe the combined lab and launcher repository.

## [0.12.0] - 2026-10-06

### Changed

- Widgets use one non-stacking page-grid order. Moving a widget changes only its cell. `zIndex` no longer controls display order or belongs in widget configuration.
- The Apps and commands sheet constrains installed application icons to a fixed 32dp box, so package artwork cannot expand a command row.
- The development image pins the current Alpine `python3` package.

### Migration

- Remove `zIndex` from every widget document under `/sdcard/Dikciz/pages/*/widgets/` before upgrading. Dikciz rejects the removed key and keeps the current home instead of applying that configuration.

## [0.11.1] - 2026-09-23

### Added

- A Dikciz scripting tutorial explains every native event, custom events, Lua policies, HTML bridge calls, self and cross-widget state, typed actions, logs, and the Android access outcomes that can stop an automation.
- The user guide now starts with APK installation and Android Home setup, then shows the resulting page search, saved HTML, appended blocks, script notification, script log, and notification digest screens.

### Changed

- The module README and user guide direct people to the scripting tutorial for events and widget automation, while the automation-control guide remains the WebSocket and MCP protocol reference.
- The bundled Workbench action list now includes `patchDom`, `appAction`, and `sendSms` with the actions it already supports.

### Fixed

- The automation and configuration references no longer omit `patchDom` from the typed action vocabulary.

## [0.11.0] - 2026-09-22

### Added

- `make dikciz-control-ready` waits for both local Dikciz control planes to
  answer through the shared forward. `make dikciz-run` now calls it after the
  launcher starts, so it does not report success before the WebSocket and MCP
  clients can connect.
- The Dikciz user guide is organized as complete tasks, with fresh emulator
  evidence for named page search, saved HTML, appended HTML blocks, script
  notifications, script logs, and notification-driven dashboard updates.

### Fixed

- `make dikciz-run` now starts the shared emulator before it installs and
  launches Dikciz. It no longer waits forever for ADB when the emulator was
  previously stopped.
- First-run control readiness now proves the live WebSocket and MCP listeners
  without requiring storage access. The full smoke tests still require the
  configured Home screen.
- The shared forward now joins the lab's edge network as well as its private
  device network. Docker now publishes the requested WebSocket and MCP ports
  on host loopback, while they remain unavailable from the LAN.

## [0.10.0] - 2026-09-21

### Added

- `make dikciz-guide-capture` regenerates every screenshot in the user guide.
  It resets the shared emulator to the bundled home, performs each documented
  step on the real device, photographs the result, and writes the images into
  `docs/images/user-guide/`. A documented step that stops working now fails the
  capture instead of leaving a stale picture in the guide.
- Page search in the home chrome. The magnifier beside the Dikciz mark opens a
  jump list of every page, each row labelled `Name (address)`. Typing filters
  on either half, so `Notes` and `2H1V` both reach the same page, and tapping a
  row goes there. Automation drives it through `launcher:page-search`,
  `launcher:page-search:query`, and `launcher:page-search:page:<pageId>`.
- Native app shortcuts can merge into an app group by dropping one tile onto
  another. Groups open as an icon grid and collapse back to a shortcut when one
  member remains.

### Changed

- The user guide is a twenty-nine step walkthrough, from first launch through
  app groups, the grid, HTML widget authoring, pages, provider widgets,
  scripts, and the system sheets, to the two control planes. Every screenshot
  in it comes from the capture command. The thirteen hand-made images it used
  before are gone.
- The launcher controls button in the bottom chrome is the Dikciz mark alone.
  The `Controls` text is gone, and the button keeps its
  `Open Dikciz launcher controls` content description for the screen reader and
  for automation.
- The page menu and the launcher control sheet print the page address beside
  the page name, for example `Page: Home (1H1V)`. That address is how Lua,
  HTML, WebSocket, and MCP already name the page.
- An app tile draws its icon as the largest square its grid cell allows,
  measured against the narrower side, with the icon and its label centred in
  the cell as a pair. The icon used to be a fixed 48dp pinned to the top of the
  cell, which left a large tile mostly empty.
- App groups are made by dropping one app tile onto another, the way a launcher
  makes a folder. The picker's `App group` entry and its checkbox form are
  gone. Dropping a third tile adds it. A group opens as a grid of its member
  icons: tap one to launch it, long press one to remove it. Removing down to a
  single app collapses the group back into a plain app shortcut in the same
  cell, keeping the widget ID so a script addressing it keeps working. The
  `appGroup` type stays in the public schema and in `addWidget`.
- Dropping a widget on an occupied cell now merges or trades instead of always
  being refused. Two app tiles merge into a group. Two widgets of the same size
  trade places, and both tiles show the trade while the finger is still down.
  A drop between different sizes is still refused. The tile under the pointer
  decides, not the corner of the dragged widget.
- An app tile is dragged from anywhere on it, and a tap anywhere on it still
  launches the app. A widget that owns its content, an HTML document, an
  Android provider view, or the script dashboard, keeps its top `24Dp` drag
  strip, because its body needs the touches for itself.

### Fixed

- The launcher's own automation-service notification is no longer an
  automation event. Android requires `startForeground` on every start command
  the service receives and each call re-posts that notification, so a script
  subscribed to notifications was handed an event the launcher caused by
  configuring itself. A script that wrote anything in response closed a loop:
  the write reloaded the configuration, the reload restarted the service, and
  the service posted the notification again. One bundled script reached two
  hundred and eighty-six status writes in six minutes this way. Notifications
  the launcher posts on a script's behalf are ordinary content and are still
  reported.
- A read that only decides whether a write can be skipped no longer ends the
  launcher. `writeAtomicFileIfChanged` compared the stored file against the
  content about to replace it without guarding the read, so a public file
  left half written by an interrupted process returned an I/O error and took
  the process down from a background thread. A failed comparison now answers
  that the content differs and the write goes ahead.
- A change written to `/sdcard/Dikciz/` from outside the launcher now reloads.
  The launcher watched the tree with Android's `FileObserver`, which reports
  the FUSE view of shared storage and never saw a file that adb, a computer
  over MTP, or the launcher's own process wrote. An edit made the documented
  way could sit on disk until something unrelated happened to trigger a
  reload. A cheap stat poll of the watched directories now backs the observers
  up while the home screen is running.
- `make dikciz-test` no longer reports failures its own suite caused. Two
  tests named a fixture their module never imported and could not be collected
  at all. Two app drawer tests launched an app and returned home without
  closing the drawer, so later tests drew their pages underneath it. The
  accessibility waits polled `accessibilitySnapshot` ten times a second, which
  exhausts the documented budget of thirty-two live descriptors in about three
  seconds and refuses the next request. A screen-off check read wakefulness
  once and caught the `Dozing` step on the way to `Asleep`. The log audit
  asserted the day's log covers every control surface the suite exercises
  while its file name sorted it ahead of most of them, so it is collected last
  now.
- The lab accepts every emulator console credential the emulator can generate.
  The credential is base64, and the check rejected the `+`, `/`, and `=` that
  alphabet contains, so a randomly drawn token broke GPS injection, sensor
  injection, incoming SMS, and every other console operation until the
  emulator was recreated.
- Deleting a widget or a page removes its public document. The store only ever
  wrote files, so every removed widget and every removed page left a document
  behind that nothing loaded. Making a group removes two widgets at once, which
  made the stale files pile up quickly. Only documents Dikciz writes are
  removed, so a foreign file keeps its directory.
- Android no longer kills the launcher process over the automation service.
  `onStartCommand` could return without ever reaching `startForeground`, once
  by skipping the call when nothing about the configuration had changed, once
  by skipping it while the service believed it was already in the foreground,
  and once by ignoring a refusal. Any of the three let the platform kill the
  whole process five seconds after `startForegroundService`, taking the home
  screen and both control planes down with it, and the belief was the worst of
  them because Android ends the foreground state on its own and the service
  had no way to hear about it. Every start command now reaches
  `startForeground`. A refusal is caught instead of escaping, and whether it
  is survivable is answered from the platform's record of the posted
  foreground notification rather than from a field the service maintains.
- Dismissing a widget's action sheet forgets every control it registered. The
  two dismissal paths kept their own lists, which had already drifted, so
  `move` survived both and `addBlock` survived one. A remote client kept seeing
  buttons for a sheet that was no longer on screen, and a tap on one was
  accepted.
- A widget hovered as a merge target no longer wears the refusal styling. The
  drop lands on an occupied cell, which the grid otherwise refuses, so the
  target looked rejected right up until the drop made a group instead.
- The page draws its grid while a widget is being moved or resized. Placement
  snaps to whole cells, so the gesture was guesswork without them.

## [0.9.0] - 2026-09-19

### Added

- Automation scripts can send an SMS. The `sendSms` action takes a dialable
  `recipient` and a `body`, divides a long body into message parts, and needs
  the `SEND_SMS` Android permission that `automationStatus` reports as
  `smsSend`. With the existing `smsReceived` event a script can now read an
  incoming message, decide a reply, and send it. Dikciz is not the default SMS
  app, so a sent message does not reach the Android SMS provider or the owner's
  messaging history, and Android limits a non-default app to about thirty
  messages in thirty minutes before it asks the owner to confirm each send.

### Changed

- A policy's `actions` list is now enforced when a script action runs. An
  action the policy does not declare is refused as `capability_denied` and
  nothing happens. A script whose policy is missing gets no actions at all.
  Actions a Dikciz HTML widget dispatches directly are unchanged, because the
  owner invokes those on the device.
- A refused action now records a machine-readable `reason` beside its outcome,
  so a log reader can select refusals without parsing outcomes.

### Fixed

- Android's Home action now saves the page it selects. The launcher returned to
  the home page on screen but kept the previously selected page in
  `config.json`, so the next process start reopened on that page.
- Only the horizontal page rail starts the app-drawer gesture. An upward drag
  that began in the page itself opened the drawer instead of scrolling page
  content, because the page viewport was an activation area and the activation
  band reached above its own rail.
- The bundled pages fill the whole page grid. Their widgets stopped one row
  short of the six-row grid, which left an empty strip under the last card and
  clipped its content.

### Migration

- Review each automation policy before upgrading. A script that returns an
  action its policy does not list stops working and records
  `capability_denied`. Add the action to the policy's `actions` list to restore
  it. The bundled scripts already declare every action they use.

## [0.8.0] - 2026-09-19

### Added

- A Dikciz HTML widget can append a named block from its own menu. The block
  saves its marked source into the already-live document, scrolls that widget
  to the new block, and does not reload the WebView. Bundled blocks cover a
  heading, a status row, an action button, and a divider.
- Settings can edit the native page grid. Columns, rows, gap, and outer padding
  apply to every page. The change is all or nothing, and it is refused with the
  offending page and widget when an existing item would collide or leave the
  new grid.
- The page menu can move the current page left, right, up, or down. A move
  swaps with the page at the immediately adjacent coordinate and leaves every
  other page in place. A direction with no adjacent page is disabled.
- A long press on the blank page rail before the first dot or after the last
  dot creates and selects a saved page at that edge of the rail.
- WebSocket and MCP expose a `gridSet` command that applies the same page-grid
  change with the same all-or-nothing result.

### Changed

- A native page is one fixed viewport. It no longer grows downward, and adding
  an item never pushes content below the visible page.
- Every top-level item owns explicit grid cells. The old `position` with `xDp`
  and `yDp` is replaced by `cell` with `column`, `row`, `columnSpan`, and
  `rowSpan`. The `minimized` flag is gone.
- Adding an item first-fits row-major on the current page. When no rectangle
  fits, the action writes nothing and reports `page_full`.
- Move and resize snap to whole cells. A move or resize that would overlap
  another item or leave the page is rejected before anything is saved.
- Page creation saves and selects the new page in one step. The provisional
  page and its confirm and cancel controls are removed.

### Migration

- The grid schema is the only layout schema Dikciz reads. A `/sdcard/Dikciz/`
  tree written by 0.7.0 or earlier carries `position`, old `size` records, or
  `minimized`, and the strict parser rejects all three. Copy the old tree first
  if you want to keep it, then either push a grid-shaped document through
  WebSocket or MCP `configReplace`, or run `make dikciz-reset` to return to the
  bundled starter home.

## [0.7.0] - 2026-09-17

### Added

- A screen-by-screen Dikciz guide now covers the bundled home, launcher
  controls, app drawer, widget library, page manager, settings, automation
  access, script dashboard, public files, ADB, WebSocket, and MCP with shared
  emulator screenshots.

### Changed

- Native page content can grow downward. Adding a widget or app shortcut now
  uses the normal gutter below the lowest current widget and scrolls to reveal
  the new item.
- WebSocket and MCP page-scroll state now reports the real native offset and
  range. Clients can use `scrollBy` and `scrollTo` to inspect and navigate
  extended page content.
- Fossify refresh comparison ignores generated Gradle output, preserves the
  fork contribution guide, and accepts only an upstream release marker newer
  than the imported marker.

### Fixed

- A full-height HTML widget no longer causes a newly added widget or shortcut
  to render on top of it.

## [0.6.0] - 2026-09-14

### Added

- Dikciz now has an always-visible native Controls route and app drawer. The
  drawer searches launchable apps by label or package name, launches a selected
  app, and exposes shortcut, app-info, uninstall, and root-backed force-stop
  actions.
- WebSocket and MCP now expose the shared app catalogue and typed app-action
  commands. The semantic UI and focused emulator checks cover the controls,
  drawer entry, search, launch, and shortcut placement.

### Changed

- New activity shortcuts are visible native tiles at the current page's usable
  top-left position. They are no longer obscured by full-page HTML content, and
  their top edge is the explicit move zone.
- Dikciz documentation now separates its release notes from retained Fossify
  upstream history and documents the native controls, app drawer, saved
  shortcuts, remote actions, and current focused verification routes.

### Fixed

- Re-entering Android Home no longer replays the ten-second Dikciz startup
  screen. An upward gesture from the horizontal page rail opens the app drawer
  instead of being lost to page navigation.

## [0.5.0] - 2026-09-13

### Added

- Dikciz now has native two-axis pages that combine HTML widgets, app
  shortcuts, app groups, third-party Android AppWidgets, and the native script
  dashboard. HTML widgets support local HTML, CSS, JavaScript, persistent
  state, automatic content height, native edit actions, and a bundled widget
  library.
- The HTML and Lua APIs now share page and widget addresses, typed Android and
  custom events, cross-widget state updates, diagnostics, and the automation
  action runtime. HTML updates patch the current document without reloading the
  widget.
- Local control now includes configured bearer authentication, device-access
  inventory, accessibility snapshots and actions, custom automation dispatch,
  script and widget diagnostics, and bounded renderer recovery.
- The bundled starter home demonstrates device status, clock, lock, app launch,
  brightness, notification, and script controls. Dikciz has its own launcher
  icon and startup screen.

### Changed

- The shared emulator is the one persistent manual and automated test phone.
  Clean resets remove only Dikciz and `/sdcard/Dikciz`, then restore the bundled
  starter home after a passed, failed, or interrupted test.
- Automation setup now presents the current Android permission, role, special
  access, accessibility, and root-shell state in one device-access inventory.
  The device remains the authority for every grant.

### Fixed

- HTML widget resize controls draw above widget content and stay within the
  native widget bounds. Page gutters and HTML card borders no longer disappear
  at viewport edges.
- HTML renderer limits reject excess widgets and documents, recover from a
  failed renderer, and keep minimized widgets out of renderer capacity.

### Migration

- Replace `text`, `toggle`, and Lua widget entries with `html`, `app`,
  `appGroup`, `provider`, or `scriptDashboard` entries before upgrading. Lua
  remains available as scripts under the public scripts tree, not as a widget
  type.

## [0.4.0] - 2026-09-10

### Added

- Dikciz now runs validated local Lua scripts from public files. Policies can
  subscribe scripts to typed Android and launcher events, then grant only the
  declared bounded actions.
- Local control planes now expose automation status, manual triggers,
  persistent command and UI events, script logs, diagnostics, screenshots,
  semantic UI dumps, and a supplied dependency-free shell client.
- Script failures are retained in bounded public logs, visible in Settings and
  the control planes, and can post a rate-limited Android notification when
  the user grants notification permission.
- Provider widgets can expose their current attached actions through stable
  semantic IDs. The lab includes a configurable fixture for provider actions,
  media controls, weather recovery, and notification actions.
- The lab can stage, compare, dry-run, and explicitly refresh the maintained
  Fossify source base from a selected local source tree.

### Changed

- Dikciz automation policies now cover typed sensors, location, Calendar,
  contacts, phone state, Health Connect daily steps, incoming SMS, clipboard,
  notification and media sessions, device administration, and selected Android
  system state. Android remains the authority for every permission and special
  access grant.
- The live-control test suite is split by behavior. Release checks use focused
  device selectors instead of source-text assertions.
- Gradle output from the provider fixture is ignored so generated files cannot
  enter a release.

### Fixed

- Page, widget, picker, resize, lock, and appearance controls keep their
  semantic state consistent through native UI and both local control planes.

## [0.3.0] - 2026-09-06

### Added

- The Dikciz home surface reflows across portrait and landscape orientation.

### Changed

- Widgets move from an invisible zone along their top edge. The visible drag
  grip is gone, and card content no longer reserves side space for it.
- The bundled `dikciz-dark` and `terminal` themes use 8 dp widget padding.
- Page indicator rails keep an equal 16 dp chrome inset on both sides, and the
  vertical rail ends level with the horizontal rail.
- Fill-page resize keeps a theme's outer widget margin inside the page
  allocation.
- Dikciz's storage-access prompt uses the bundled Dikciz Dark theme, so the
  first screen after installation matches the bundled home.
- `make dikciz-test` builds the upstream-compatible Fossify core flavour
  alongside the Dikciz flavour, so the Home-role tests install a core build
  from the current source instead of whichever APK was already on disk.
- The physical-device check installs through Android's package manager for the
  primary user and forwards the MCP endpoint alongside the WebSocket.

### Fixed

- Android's provider bind request carries the provider's user profile, so
  binding works on devices that expose more than one profile.
- The physical-device runner waits for Android to publish Dikciz's Home
  activity and recreate its debug app sandbox after a clean installation.
- Android Home starts now require the requested package to hold the verified
  Home role before the system resolver is used.
- The physical-device check stops and uninstalls only Dikciz's debug package,
  removes only its public configuration tree, then installs the current build.
  It never reboots the configured phone.
- The physical-device check re-enables only the current Dikciz package after
  replacement, so a retained disabled-package state cannot hide its Home
  activity.

### Migration

- The physical-device check no longer backs up or restores Dikciz files, the
  Android Home role, or package data. It replace-installs the current build
  before it clears the app's standard private data and public tree, resets to
  the bundled home, and leaves Dikciz holding the Home role. Copy
  `/sdcard/Dikciz` yourself first when you need the previous configuration.

## [0.2.0] - 2026-09-06

### Added

- Public Dikciz configuration tree rooted at `/sdcard/Dikciz/config.json`,
  with separate page, widget, and reusable theme files.
- Native page and widget controls for app shortcuts, provider widgets, editing,
  styling, locking, resizing, page creation, and two-axis navigation.
- Control-plane seed, reset, and bounded semantic wait commands through both
  WebSocket and MCP.
- An opt-in, single-device physical-phone check that fresh-installs the debug
  build, preserves the user's Dikciz files and Home role, and grants storage
  access through Android Settings.

### Changed

- Widgets remain inside the page viewport. Fill-page resize actions keep the
  active resize selection visible until the user finishes it.
- Page rails cycle one page at a time when their empty track is tapped, and
  their dot spacing no longer wastes page space.
- The lab clears only stale Android AVD lock files after an unexpected emulator
  exit.

### Fixed

- Dikciz's storage-access and configuration-error prompts now lay out their
  title, message, and action separately.

### Migration

- On first start after upgrading, Dikciz converts
  `/sdcard/Dikciz/dikciz.config.json` into the public tree and archives the
  old file as `dikciz.config.migrated-v2.json`.

## [0.1.0] - 2026-09-04

### Added

- Docker-only Android build, emulator, browser inspection, and device-control
  workflow.
- Dikciz, a programmable launcher flavour with a JSON-defined two-axis home,
  native and Android provider widgets, local WebSocket and MCP controls, and
  semantic UI automation.
- Launcher themes, wallpaper backgrounds, per-widget appearance, bundled and
  local fonts, page and widget locks, default Home-page selection, and
  persistent widget references.

### Changed

- Browser VNC now presents the full Android viewport with visible navigation
  controls and keyboard forwarding.
- Dikciz remains additive to the tracked Fossify Launcher source base so future
  Android and launcher updates come from the upstream source fork.
