# EcoPlog — Product Structure & Two-Person Work Plan

> Companion to `ecoplog_app_architecture_features_specification.md`. Answers: **what are we building, in what order, and who owns what** (two developers).

## 1. The idea

You're on your daily walk and pass a trash-strewn corner of a park. You take a photo; **AI scans it**, identifies the waste, estimates the volume and lists the gear (heavy-duty gloves, trash pickers…). The app pins a **Clean-Up** on the map, turning the polluted spot into a community event. Nearby runners and neighbours get a **notification**, **RSVP**, grab their gear and meet there.

When everyone arrives, they tap **Start Activity**. CoreLocation records the route, HealthKit supplies calories, heart rate and steps, and live progress shows on the **Dynamic Island**. When the area is clean, the app opens a **ghost camera** (the original photo as a translucent overlay) to shoot a matching **After** photo. On finish, the app compiles HealthKit metrics + route map + Before/After into a **video reel with a slider transition**, ready to export to an **Instagram Story**.

### Vocabulary (use these words everywhere, in code and UI)
| Term | Meaning |
|---|---|
| **Spot** | Photographing a polluted place and letting AI analyse it |
| **Clean-Up** | The pin/event created from a Spot: photo, waste, gear, location, RSVPs, status |
| **Activity** | One person's tracked workout (route + HealthKit + photos), free or attached to a Clean-Up |
| **Reel** | The exported Before/After video with stats |

## 2. Product structure

### 2.1 Core loop (everything we build serves this)
```
 SPOT ──► PIN ──► NOTIFY & RSVP ──► START ACTIVITY ──► AFTER PHOTO ──► REEL ──► INSTAGRAM STORY
 photo   Clean-Up  nearby people     route + HealthKit   ghost camera   slider   share
 + AI    on map    join              + Dynamic Island    matches Before  video
```
Key insight: **the Before photo is the Spot photo.** It is captured once, at scan time, together with GPS position and compass heading, and reused later as the ghost overlay and as the left side of the Reel.

### 2.2 Screen map (4 tabs + Activity flow)
| Tab / flow | Screens |
|---|---|
| **Map** (home) | Map of Clean-Ups (open / scheduled / live / done), filters, Clean-Up detail (photo, waste chips, gear list, attendees, RSVP, "Start Activity") |
| **Spot** | Camera → AI analysing → result (waste, volume, gear, hazard) with editable chips → schedule (now / date, capacity) → publish |
| **Activity** (full-screen flow, launched from a Clean-Up or the center button) | Pre-start → live tracking (map, time, distance, kcal, HR, steps, bag counter) → ghost camera After → finish → impact log → summary → Reel preview → share |
| **Feed** | Finished activities/reels from the community, kudos (SHOULD) |
| **Me** | Profile, history, totals, badges/streaks (SHOULD), settings, notification preferences |

### 2.3 Domain model (shared contract, defined Day 0)
- `User` (id, name, avatar, totals)
- `CleanUp` (id, coordinate, beforePhotoURL, beforeHeading, wasteTypes, severity, estimatedBags, gear[], hazard?, startsAt?, capacity?, hostId, status: open / scheduled / live / done, attendeeIds, doneActivityIds)
- `RSVP` (cleanUpId, userId, createdAt)
- `Activity` (id, userId, cleanUpId?, startedAt, endedAt, route `[RoutePoint]`, distance, duration, elevation, kcal, avgHR, steps, `ImpactLog`, afterPhotoURL?, reelURL?)
- `ImpactLog` (bags, kg, itemCounts by category)
- `ScannerResult` (wasteTypes, severity, estimatedBags, gear, hazard, peopleNeeded)
- `Post` (activityId, kudos, comments) — SHOULD
- `Badge` — SHOULD

### 2.4 Tech stack
SwiftUI + `@Observable` (iOS 17), SwiftData (local/offline), CoreLocation, MapKit, HealthKit, CoreMotion (`CMPedometer` live steps), Vision, AVFoundation (camera + reel), ActivityKit (Live Activity / Dynamic Island, needs a Widget Extension target), `ImageRenderer`, UserNotifications + APNs, Supabase (Postgres + PostGIS, Storage, Auth with Apple, Edge Functions).

## 3. Features

### 3.1 MUST (the story above, end to end)
1. AI Spot: photo → waste types, volume, gear list, hazard flag
2. Clean-Up pinned on the map with RSVP
3. Nearby notification when a Clean-Up is created
4. Start Activity: route (CoreLocation) + HealthKit (kcal, HR, steps) + live progress
5. Dynamic Island / Lock Screen Live Activity
6. Ghost-camera After photo aligned to the Before
7. Reel: slider transition Before→After + route + stats, 9:16
8. Export to Instagram Story

### 3.2 SHOULD
Impact log (bags/kg), impact equivalents ("≈ N bottles"), Clean-Up verification (proximity + After photo), face blur on public photos, hazard safety screen, feed + kudos, activity history, badges/streaks, still badge card as a fallback to the Reel.

### 3.3 STRETCH
Territory heatmap with decay, Apple Watch companion, "Start Plog" App Intent / Action Button, WeatherKit warning, group chat, sponsor challenges/leaderboards.

## 4. Technical notes that shape the plan
- **HealthKit on iPhone (iOS 17)**: no `HKLiveWorkoutBuilder`. Use `HKWorkoutBuilder` + `HKWorkoutRouteBuilder` to *save* the workout at the end. Live numbers: steps from `CMPedometer`; heart rate from Apple Watch via `HKAnchoredObjectQuery` (shows "—" without a Watch); calories = MET estimate live (labelled "estimated"), replaced by HealthKit active energy if available at the end.
- **Notifications "nearby"**: push needs APNs and a server. Each user's device stores a coarse location (geohash, updated when the app is active/significant location change); a Supabase Edge Function on Clean-Up insert selects users within ~3 km and sends APNs. Fallback for the demo: a "notify nearby" local notification on a second phone.
- **Ghost camera**: Before photo stores coordinate + compass heading; the After camera shows it at ~35% opacity, plus a "move closer / turn left" hint from heading difference.
- **Reel**: `AVAssetWriter` renders frames from a SwiftUI/Core Animation composition (slider wipe, animated route polyline, stat counters); 1080×1920, ~10-15 s, H.264.
- **Instagram Stories**: `instagram-stories://share?source_application=<Meta App ID>` with pasteboard `com.instagram.sharedBackgroundVideo` (or image + sticker). Needs `LSApplicationQueriesSchemes` and a Meta App ID. Fallback: `UIActivityViewController`.
- **AI**: on-device Vision pre-check + cloud vision through a thin Edge Function that holds the API key (never ship the key in the app), returning strict JSON (`ScannerResult`). Timeout + manual entry fallback.
- Real device needed for camera, HealthKit sensors, background GPS, Live Activities, push. Simulator: GPX route simulation.

## 5. Architecture rules (so two people don't collide)
1. **Feature folders, one owner each.** `project.yml` globs `MyApp/`, so new files need no project edits.
   ```
   MyApp/
     App/                (shell, tabs — P2)
     Core/               (models, repository protocols, mocks, DesignSystem ✅ — via PR)
     Features/
       Activity/         P1   (session, tracking, HealthKit, live activity)
       Camera/           P1   (ghost camera; scanner capture reuses it)
       Reel/             P1   (video engine)
       Spot/             P2   (AI, result, publish)
       Map/              P2   (clean-up map, detail, RSVP)
       Feed/             P2
       Profile/          P2
       Share/            P2   (Instagram, share sheet, still badge)
     Services/
       Backend/          P2
       Notifications/    P2
   ```
2. **Contracts first, mocks always.** Day 0: models + repository protocols + in-memory mocks in `Core/`. Everyone works on mocks until the backend is live.
3. **Dependencies via SwiftUI `Environment`** (`@Environment(\.cleanUpRepository)`).
4. **Swift 6 vs CoreLocation/HealthKit delegates**: isolate managers with `@MainActor`, or drop to language mode 5 for speed (recommended for a hackathon).
5. **Stop committing `MyApp.xcodeproj`**: add to `.gitignore`, `git rm -r --cached MyApp.xcodeproj`, run `xcodegen` after pulling. Per-dev signing via an untracked `Local.xcconfig`.
6. **Git**: protected `main`, branches `p1/…` / `p2/…`, squash-merge PRs, `Core/` changes reviewed by the other person, merge at least twice a day.
7. **Design system is done** (`Core/DesignSystem/`): use `Eco.*` colors, `.eco*` fonts, `.eco` button styles, `.ecoCard()`. No hard-coded colors in features.

## 6. Day-0 shared foundation (~half a day, pair up)
| Task | Who |
|---|---|
| ✅ Design system (dark green theme) | done |
| `project.yml`: HealthKit, background location, Live Activity (`NSSupportsLiveActivities`), push entitlement, Info.plist usage strings (location always/when-in-use, camera, photo library add, health share/update, motion), `LSApplicationQueriesSchemes: instagram-stories`, Widget Extension target | P1 |
| Domain models + repository protocols + mocks (`CleanUpRepository`, `ActivityRepository`, `ScannerService`) | P2 draft → both sign off |
| App shell: tab bar, environment injection, placeholder screens | P2 |
| Supabase project, schema draft, Sign in with Apple, keys in untracked config | P2 |
| `.gitignore` the xcodeproj, `Local.xcconfig`, branch rules | P1 |
| Close the open decisions in §10 | both |

## 7. Ownership

### 👤 Person 1 — **Activity & Reel** (everything after "Start Activity", plus the video)
Owns the tracked workout, the sensors, the camera and the video.

| Feature | Details / frameworks | Size |
|---|---|---|
| Session state machine | idle → running → paused → finished, `@Observable ActivitySession`, `start(context: .free / .cleanUp(id))` | M |
| GPS route tracking | `CLLocationManager`, background updates, accuracy filter, auto-pause, distance/pace/elevation, live `MapPolyline` | L |
| HealthKit | Authorization; live steps (`CMPedometer`), HR (`HKAnchoredObjectQuery`), MET calorie estimate; save `HKWorkout` + `HKWorkoutRouteBuilder` on finish | L |
| Live Activity / Dynamic Island | Widget extension; compact, expanded and Lock Screen layouts: time, distance, kcal, bags; updated from the session | M |
| Camera + ghost overlay | `AVCaptureSession` camera view shared with Spot (P2 embeds it); overlay at ~35% opacity, heading/position hint | M |
| Impact log | Bag/kg counters, gloves-friendly big buttons (also a +1 bag button on the live screen) | S |
| Local persistence | SwiftData for `Activity`, crash recovery of an in-progress session, offline queue | M |
| Activity summary + history | Post-finish summary with route map, history list/detail | M |
| **Reel engine** | Slider Before→After transition, animated route, stat overlay, 9:16 `AVAssetWriter` export; `ReelRenderer.render(activity, before, after) async -> URL` | L |
| Reel preview UI | Preview player, re-render, "Share" button hands the file URL to P2's `ShareService` | S |
| App Intent "Start Activity" | STRETCH | S |

**Exposes:** `ActivityRepository` local impl, `ActivitySession.start(context:)`, `CameraView(ghost: UIImage?)`, `ReelRenderer`.
**Needs from P2:** Clean-Up (with Before photo + heading) to attach; upload of finished Activity; `ShareService`.

### 👤 Person 2 — **Spot & Community** (everything before "Start Activity", the backend, and sharing)
Owns the AI, the map, people, notifications, the server, and leaving the app.

| Feature | Details / frameworks | Size |
|---|---|---|
| Backend | Supabase schema + RLS (users, clean_ups, rsvps, activities, device tokens), PostGIS "nearby" query, Storage buckets, Sign in with Apple, Swift service layer implementing the repository protocols. **Ships Clean-Up + RSVP tables first (P1's Start Activity depends on them).** | L |
| Spot capture | Uses P1's `CameraView`; saves coordinate + heading with the photo | S |
| AI pipeline | Vision pre-check ("is this waste?") + Edge Function → cloud vision → strict `ScannerResult` JSON; timeout + manual fallback; fixtures for tests | L |
| Result & publish UI | Editable waste/gear chips, hazard banner, schedule (now / date), capacity, "Publish Clean-Up" | M |
| Map | MapKit map with clustered Clean-Up annotations by status, filters, "near me", Clean-Up detail sheet | L |
| RSVP | Join/leave, live attendee count, capacity, gear checklist ("I'm bringing gloves") | M |
| Notifications | APNs registration, coarse-location upload, Edge Function to notify users within radius, reminders before `startsAt`, "Start Activity" deep link into P1's flow | L |
| Share | `ShareService.share(reelURL / image)`: Instagram Stories pasteboard hand-off, share-sheet fallback, sticker/hashtags | M |
| Upload / sync | Upload finished Activity + After photo + Reel, mark Clean-Up done, retry queue | M |
| Feed + kudos | Paginated feed of finished activities, kudos, report/block | M (SHOULD) |
| Profile + history + badges | Totals, streaks, impact equivalents, notification prefs | M (SHOULD) |
| Verification + face blur | Proximity + After photo check; Vision face blur before upload | M (SHOULD) |
| Safety screen | Hazard → "don't touch, report to the city" | S (SHOULD) |
| App shell | Tabs, routing, deep links | S |
| Territory heatmap | STRETCH | M |

**Exposes:** `CleanUpRepository`, real `ActivityRepository` upload, `ScannerService`, `ShareService`.
**Needs from P1:** `CameraView`, finished `Activity`, `ReelRenderer` output.

### Load check
Both have two L-size engines. P1 is sensor/media-heavy (GPS, HealthKit, ActivityKit, AVFoundation), P2 is server/integration-heavy (backend, AI, push, map). To keep P2 from becoming the bottleneck, P1 takes the camera and the reel, P2 takes sharing. If P2 falls behind, move Feed/Profile/Verification to "cut", not to P1; if P1 falls behind, cut the Live Activity's expanded layout and the animated route first.

## 8. Milestones & cut line
| Milestone | Goal | Definition of done |
|---|---|---|
| **M0 Foundation** | Both can build, run, commit | §6 done; app launches on 2 phones; tabs + mocks wired |
| **M1 Slices on mocks** | Each half works alone | P1: walk with GPS + HealthKit numbers, Dynamic Island updating, ghost camera works, Reel renders from sample photos. P2: photo → `ScannerResult` → Clean-Up on map (mock store), RSVP UI |
| **M2 Real data** | Backend live | Auth; Clean-Ups visible on two phones; RSVP works; push received on the second phone |
| **M3 Integration** | The story works end to end | Spot → pin → notify → RSVP → Start Activity from the Clean-Up → After via ghost camera → finish → Reel → Instagram Story. **This is the demo.** |
| **M4 Polish & demo** | Judge-ready | SHOULD items, empty/error/permission states, seeded demo data, 2-minute script, screen-recording backup |

**If time is short (48 h):** keep the MUST list in §3.1; replace push with local notification + realtime map update; skip feed, badges, verification, face blur; Reel may fall back to a still Before/After image with the stats card.

## 9. Integration contracts
| Contract | Producer → Consumer | Shape |
|---|---|---|
| `CleanUpRepository` | P2 → P1, P2 | `create`, `nearby(coord, radius)`, `rsvp`, `complete(activityId)` |
| `ActivityRepository` | P1 (local) + P2 (remote) | `save`, `history`, `upload(activity)` |
| `ActivitySession.start(context:)` | P1 ← P2 map's "Start Activity" | context = `.free` or `.cleanUp(CleanUp)` |
| `CameraView(ghost:)` | P1 → P2 (Spot capture) | returns image + coordinate + heading |
| `ScannerService.analyse(image)` | P2 (proxy) | returns `ScannerResult`, versioned JSON, tested with fixtures |
| `ReelRenderer.render(...)` | P1 → P2 | returns local video `URL` |
| `ShareService.share(reelURL:)` | P2 ← P1's reel preview | Instagram Stories / share sheet |
| Design system | Core | `Eco.*`, `.eco*` |

**Sync points:** 10-minute daily standup; integration sessions at the end of M1 and M2; feature freeze before M4.

## 10. Open decisions (close on Day 0)
1. Backend: **Supabase (recommended: PostGIS, Storage, Edge Functions)** vs Firebase vs CloudKit.
2. AI: cloud vision via Edge Function (recommended) vs on-device-only CoreML (needs a dataset such as TACO, stretch).
3. Swift 6 strict concurrency vs Swift 5 mode.
4. Timeline (48 h vs multi-week) → where the cut line falls.
5. Meta App ID for Instagram Stories: who registers it.
6. Apple Developer accounts, paid team for push + HealthKit + Live Activities on real devices.
7. Who has an Apple Watch (needed to demo live heart rate).

## 11. Risks
| Risk | Mitigation |
|---|---|
| Background GPS killed or inaccurate | Test on device at M1, accuracy filter, crash recovery |
| Live HR/calories without a Watch on iPhone | MET estimate labelled "estimated", HR shown only when available |
| Push/geo notification complexity | Edge Function + geohash; local-notification fallback for the demo |
| Reel export slow or buggy | Prototype the renderer at M1 with sample images; still-image fallback |
| AI returns junk / slow | Strict schema, fixtures, timeout, manual entry, seeded demo photos |
| P2 overloaded | P2 ships mock contracts on Day 0; SHOULD items are first to cut |
| API key leakage | Key only in the Edge Function |
| Fake/abusive content | Report/block, face blur, verification, RLS |
| Merge conflicts | Feature folders, ignored `.xcodeproj`, small PRs |
| Live demo fails | Seeded data, recorded backup, rehearsed route on a real device |

## 12. Definition of done (per feature)
Runs on a real device; handles permission-denied, offline and empty states; has a mock/fixture path; uses the design system; merged to `main` with a short PR note; demo-able in under 30 seconds.
