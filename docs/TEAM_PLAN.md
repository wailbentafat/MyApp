# EcoPlog — Product Structure & Team Work Plan

> Companion to `ecoplog_app_architecture_features_specification.md`. This file answers: **what exactly are we building, in what order, and who owns what.**

## 1. The idea in one paragraph
EcoPlog is Strava for cleaning up the planet. A user starts a *Plog* (a walk/run where they pick up litter), the app records route, time, distance and calories (HealthKit), guides a **Before** and **After** photo, and logs what was collected. At the end they get a shareable **Impact Badge** / reel for Instagram Stories. Users can also **spot** pollution: snap a photo, AI identifies the waste and the gear needed, and a public **Clean-Up Beacon** appears on the community map for others to claim or join as a group event.

## 2. Product structure

### 2.1 Core loop (everything we build serves this)
```
 SPOT  ──►  JOIN/CLAIM  ──►  PLOG  ──►  PROVE  ──►  SHARE  ──►  INSPIRE
 (AI photo   (beacon or       (track     (before/    (badge,     (feed, kudos,
  → beacon)   expedition)      route,     after +     reel,       streaks,
                               health)    impact log) IG story)   territory)
```

### 2.2 Screen map (5 tabs)
| Tab | Screens |
|---|---|
| **Home / Feed** | Community feed, activity detail, comments, kudos ("Eco-Boosts") |
| **Map** | Beacon map, beacon detail, expedition detail + RSVP, territory overlay |
| **Plog (center, big button)** | Pre-start sheet → live tracking → camera (before/after) → finish → impact log → summary + share |
| **Spot** | Camera → AI result (waste, gear, severity) → confirm → beacon created |
| **Me** | Profile, stats, history, badges, streaks, settings |

### 2.3 Domain model (shared contract, defined Day 0)
- `User` (id, name, avatar, totals, streak)
- `Plog` (id, userId, startedAt, endedAt, route `[RoutePoint]`, distance, duration, elevation, kcal, avgHR, steps, `ImpactLog`, beforePhoto, afterPhoto, beaconId?, expeditionId?, visibility)
- `ImpactLog` (bags, kg, itemCounts by category)
- `Beacon` (id, coordinate, photoURL, wasteTypes, severity, gearNeeded, estimatedBags, status: open/claimed/cleaned, createdBy, clearedByPlogId?)
- `Expedition` (id, title, coordinate, startsAt, hostId, attendees, beaconId?, capacity)
- `Post` (plogId, kudos, comments)
- `Badge` / `Achievement`

### 2.4 Tech stack
SwiftUI + `@Observable` (iOS 17), SwiftData (local/offline cache), CoreLocation, MapKit, HealthKit, Vision, PhotosUI/AVFoundation, ActivityKit (Live Activity, needs a Widget Extension target), `ImageRenderer`, Supabase Swift SDK.

## 3. Feature list

### 3.1 From the spec (kept)
Activity tracking, HealthKit metrics, before/after capture with ghost overlay, impact log, AI pollution scanner, auto-generated beacons, social cards, before/after video, IG Stories deep link, map hub, group expeditions, feed, territory heatmap + decay, reel builder, leaderboards/sponsor challenges.

### 3.2 New proposals (matching the idea)
| # | Feature | Why it fits | Uses |
|---|---|---|---|
| 1 | **Auto face/plate blur** on all public photos | Photos are taken in public; privacy is a trust-blocker | Vision `VNDetectFaceRectanglesRequest` |
| 2 | **Beacon verification**: After photo + GPS proximity closes a beacon; AI compares to Before | Stops fake clean-ups, makes impact credible | Vision + CoreLocation |
| 3 | **Hazard safety flow**: needles, chemicals, glass → "Don't touch, report to city" + call/report link | Real-world safety, differentiates from a toy | AI result flag |
| 4 | **Impact equivalents** (kg collected → "≈ N plastic bottles kept out of the ocean") | Makes stats shareable and emotional | pure logic |
| 5 | **Streaks, badges, weekly goals** | Retention, Strava-style | SwiftData + backend |
| 6 | **Live Activity + Dynamic Island** (time, distance, bags) | Native-feeling, demo-friendly | ActivityKit |
| 7 | **Siri / App Intents / Action Button: "Start Plog"** | Hands-free, gloves on | App Intents |
| 8 | **Gear checklist** generated from a beacon; "I'm bringing gloves" | Coordinates group events | AI output |
| 9 | **Weather + air-quality warning** before starting | Safety | WeatherKit (stretch) |
| 10 | **Apple Watch companion** (start/stop, bag counter) | Real HealthKit live data | watchOS (stretch, post-MVP) |
| 11 | **Offline-first plogging** (sync later) | Trails have no signal | SwiftData queue |
| 12 | **Sponsor quests / council challenges** | Monetization story for judges | backend only |

## 4. Architecture rules (so 3 people don't collide)
1. **Feature folders, one owner each.** New Swift files need no project changes because `project.yml` globs `MyApp/`.
   ```
   MyApp/
     App/                 (shell, tab bar — P3, tiny)
     Core/                (models, protocols, design system, mocks — everyone, via PR)
     Features/
       Tracking/          P1
       Capture/           P1
       Scanner/           P2
       Map/               P2
       Expeditions/       P2
       Feed/              P3
       Share/             P3
       Profile/           P3
     Services/
       Backend/           P3
   ```
2. **Contracts first, mocks always.** Day 0 we define models and repository protocols in `Core/` plus in-memory mocks (`MockPlogRepository`, `MockBeaconRepository`…). Every feature runs on mocks until the real backend lands, so nobody blocks anybody.
3. **Injected dependencies** via SwiftUI `Environment`, e.g. `@Environment(\.beaconRepository)`.
4. **Swift 6 strict concurrency will fight CoreLocation/HealthKit delegates.** Decision at Day 0: keep Swift 6 and isolate managers with `@MainActor`, or drop to language mode 5 for speed (recommended for a hackathon).
5. **Stop committing `MyApp.xcodeproj`**: add to `.gitignore`, `git rm -r --cached`, everyone runs `xcodegen` after pulling. Removes the #1 merge-conflict source. Per-dev signing via an untracked `Local.xcconfig` (`DEVELOPMENT_TEAM`, unique bundle-id suffix).
6. **Git:** `main` protected, short-lived branches `p1/…`, `p2/…`, `p3/…`, squash-merge PRs, changes under `Core/` need one review from another person. Merge to main at least twice a day.
7. **Real device required** for camera, HealthKit sensors, background GPS, Live Activities. Simulator: use Xcode's GPX route simulation for tracking.

## 5. Day-0 shared foundation (all three, ~half a day, pair up)
| Task | Who |
|---|---|
| Fix `project.yml`: HealthKit + background location + Live Activity entitlements, Info.plist usage strings (location always/when-in-use, camera, photo library add, health share/update, motion), `LSApplicationQueriesSchemes: instagram-stories`, Widget Extension target | P1 |
| Domain models + repository protocols + mocks in `Core/` | P3 (draft) → all sign off |
| ✅ **Done** — Design system in `Core/DesignSystem/` (dark green theme: `Eco` colors, `.eco*` fonts, `.eco` buttons, `.ecoCard()`, `EcoStatTile`, `EcoChip`; root `.ecoTheme()`). Remaining: app icon placeholder, bundle Poppins/Inter fonts | P2 |
| App shell: 5-tab `TabView`, routing, environment injection, empty placeholder screens per feature | P3 |
| Supabase project, schema draft, Sign in with Apple, keys in untracked config | P3 |
| Decisions in §9 closed | all |

## 6. Ownership

### 👤 Person 1 — **Plog Engine** (tracking, health, capture)
Owns everything that happens *while the user is plogging*.

| Feature | Details / frameworks | Size |
|---|---|---|
| Session state machine | idle → running → paused → finished, `@Observable PlogSession` | M |
| GPS route tracking | `CLLocationManager`, background updates, accuracy filter, auto-pause, distance/pace/elevation, live `MapPolyline` | L |
| HealthKit | Authorization flow; save `HKWorkout` (walking/running) + `HKWorkoutRouteBuilder`; read HR, steps, active energy; **MET-based calorie fallback** (no live builder on iPhone in iOS 17, use Watch data when present) | L |
| Live Activity | Widget extension, Lock Screen + Dynamic Island: time, distance, bags | M |
| Before/After capture | Custom camera (`AVCaptureSession`); "before" saved with location + heading; **ghost overlay** of the before photo at 30% when taking "after" | M |
| Impact log | Bag/kg/item counters (quick +/- UI, big gloves-friendly buttons) | S |
| Local persistence | SwiftData store for `Plog`, offline queue, crash recovery of an in-progress session | M |
| Activity summary + history | Post-finish summary screen, list, detail with route map | M |
| App Intent "Start Plog" | STRETCH | S |

**Exposes to others:** a finished `Plog` value (route, stats, photos, impact) via `PlogRepository`; `PlogSession.start(beacon:expedition:)` entry point (used by P2).
**Needs from others:** upload of Plog (P3); beacon/expedition to attach (P2).

### 👤 Person 2 — **Spot & Discover** (AI scanner, beacons, map, expeditions)
Owns everything that turns a photo into an action and everything on the map.

| Feature | Details / frameworks | Size |
|---|---|---|
| Scanner camera | One-tap capture, from Spot tab or mid-plog quick button (saves location) | S |
| AI analysis pipeline | (a) On-device Vision pre-check (`VNClassifyImageRequest`) "is this waste?" + face blur; (b) cloud vision call through a thin proxy (Supabase Edge Function holding the key; Claude vision) returning **strict JSON**: `wasteTypes[]`, `severity`, `estimatedBags`, `gear[]`, `hazard`, `peopleNeeded`. Timeout + graceful manual-entry fallback | L |
| Result & confirm UI | Editable chips for waste/gear, hazard warning banner, "Create beacon" | M |
| Beacons | Create/read/claim/complete; statuses; nearby query (PostGIS); beacon detail with photo, gear checklist | M |
| Beacon verification | "Mark cleaned" requires P1's After photo + proximity check; optional AI before/after comparison | M |
| Map hub | MapKit `Map` with clustered annotations (beacons, expeditions, recent cleaned zones), filters, "near me" | L |
| Group expeditions | Create, list, RSVP with live count, capacity, host tools, per-expedition comment thread (real-time chat = STRETCH) | M |
| Territory / heatmap + decay | Grid-cell overlay (geohash/H3-style), color by recency, decay over time | STRETCH |
| Safety flow | Hazard → "don't touch, report" screen | S |

**Exposes:** `BeaconRepository`, `ExpeditionRepository`, "Start plog for this beacon" action.
**Needs from others:** Plog completion to close a beacon (P1); tables + edge function hosting (P3); design system is P2's own.

### 👤 Person 3 — **Social & Share** (backend, feed, badges, export)
Owns identity, data, the community feed and everything that leaves the app.

| Feature | Details / frameworks | Size |
|---|---|---|
| Backend | Supabase schema + RLS, Sign in with Apple, Storage buckets (photos/reels), Swift service layer implementing all repository protocols; **delivers Beacon/Expedition tables first (P2 depends)** | L |
| Sync engine | Upload finished plogs from P1's offline queue; retry | M |
| Community feed | Paginated feed, activity card, kudos, comments, follow, report/block | M |
| Profile & stats | Totals, history, streaks, weekly goal | M |
| Gamification | Badges/achievements engine, impact equivalents, leaderboards (STRETCH: sponsor quests) | M |
| **Impact Badge / social cards** | SwiftUI card templates (map polyline snapshot via `MKMapSnapshotter`, stats, photos) rendered with `ImageRenderer` at 1080×1920 and 1080×1080 | M |
| **Instagram Stories export** | `instagram-stories://share` with pasteboard items (`com.instagram.sharedBackgroundImage`/`Video`, sticker image); needs a Meta App ID; fallback `UIActivityViewController` (TikTok goes through the share sheet, not a URL scheme) | M |
| **Before/After reel** | `AVAssetWriter` + Core Animation compositing: wipe/fade between photos, animated route, stat overlay, 9:16, ~15 s | L |
| Notifications | Nearby beacon, expedition reminders, kudos (STRETCH) | S |
| App shell + Me tab | Tab bar/routing, settings | S |

**Exposes:** all repositories (real implementations), `ShareService.share(plog:)`.
**Needs from others:** finished `Plog` (P1); beacon UI (P2).

### Load check
Each person has one L-heavy engine, ~2 M features and stretch items. P3 carries the most integration risk (backend), so P3 ships the mock-first contracts on Day 0 and P1/P2 never wait on it.

## 7. Milestones & cut line
| Milestone | Goal | Definition of done |
|---|---|---|
| **M0 Foundation** | Everyone can build, run, commit | §5 complete; app launches on 3 phones; 5 empty tabs; mocks wired |
| **M1 Vertical slices on mocks** | Each feature works alone | P1: track a walk, save HKWorkout, see it in history. P2: photo → AI JSON → beacon on map (mock store). P3: feed renders mock plogs; badge PNG renders from a sample plog |
| **M2 Real data** | Backend live | Auth works; plogs upload; beacons shared across two phones; feed shows real activity |
| **M3 Integration** | The core loop works end to end | Spot → beacon → start plog from beacon → before/after → finish → beacon marked cleaned → badge → IG Story. **This is the demo path.** |
| **M4 Polish & demo** | Judge-ready | Live Activity, reel, face blur, empty/error states, seeded demo data, 2-minute demo script, screen recording backup |

**MUST:** M0–M3 (tracking, HealthKit workout, before/after, AI beacon, map, feed, badge + IG story).
**SHOULD:** Live Activity, expeditions/RSVP, reel, face blur, streaks/badges, verification.
**STRETCH:** territory decay, Watch app, App Intents, sponsor quests, WeatherKit, real-time chat.
If time is short (48h): cut expeditions chat, territory, reel (keep the still badge), and leaderboards.

## 8. Integration contracts (who calls whom)
| Contract | Producer → Consumer | Shape |
|---|---|---|
| `PlogRepository` | P1 ↔ P3 | `save(plog)`, `history()`, `upload queue` |
| `BeaconRepository` | P2 ↔ P3 | `create`, `nearby(coord, radius)`, `claim`, `complete(plogId)` |
| `ExpeditionRepository` | P2 ↔ P3 | `create`, `list(near:)`, `rsvp` |
| `PlogSession.start(context:)` | P2 → P1 | context = free / beacon / expedition |
| `ScannerResult` JSON | proxy → P2 | fixed schema, versioned, unit-tested with fixtures |
| `ShareService.share(plog)` | P1's summary screen → P3 | called from the finish screen |
| Design system | P2 → all | tokens + components in `Core/DesignSystem` |

**Sync points:** daily 10-minute standup, an integration session at the end of M1 and M2, a feature freeze before M4.

## 9. Open decisions (close on Day 0)
1. Backend: **Supabase (recommended, PostGIS)** vs Firebase vs CloudKit (zero server, weaker geo/moderation).
2. AI: cloud-vision-via-proxy (recommended, fastest to good results) vs on-device-only CoreML (needs a labelled dataset such as TACO; better as a stretch). Needs an API key and a place to host the proxy.
3. Swift 6 strict concurrency vs Swift 5 mode.
4. Timeline (48h hackathon vs multi-week) → adjust the cut line.
5. Instagram Stories requires a registered Meta App ID; who creates it.
6. Apple Developer accounts / devices for each teammate (HealthKit and Live Activities need real signing).

## 10. Risks
| Risk | Mitigation |
|---|---|
| Background GPS killed or inaccurate | Test on device early (M1), accuracy filter, crash recovery |
| No live workout builder on iPhone → calories | MET fallback + Watch data when available; label "estimated" |
| AI returns junk / slow | Strict JSON schema, fixtures, timeout, manual-entry fallback, seeded demo photos |
| Backend blocks others | Mock-first contracts, P3 ships beacon tables first |
| Fake/abusive content | Report/block, face blur, verification, RLS |
| API key leakage | Key only in the proxy, never in the app |
| Merge conflicts | Feature folders, ignored `.xcodeproj`, small PRs |
| Demo fails live | Seeded data, prerecorded backup, tested demo route on real device |

## 11. Definition of done (per feature)
Runs on a real device; handles permission-denied, offline and empty states; has a mock/fixture path; merged to `main` with a short PR note; demo-able in under 30 seconds.
