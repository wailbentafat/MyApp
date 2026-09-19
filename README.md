# EcoPlog

**Strava for cleaning up the planet.** Spot pollution, let AI plan the cleanup, get neighbours to join, track the workout, and share a Before/After reel with your fitness stats.

## The idea

You're on a walk and pass a trash-strewn corner of a park. Take a photo: AI identifies the waste, estimates the volume and lists the gear (gloves, trash pickers…). The app pins a **Clean-Up** on the map. Nearby runners are notified, RSVP, grab their gear and meet there.

When everyone arrives, tap **Start Activity**: CoreLocation records the route, HealthKit supplies calories, heart rate and steps, and progress shows live on the Dynamic Island. When the area is clean, a ghost-camera overlay helps you shoot a matching **After** photo. The app then builds a **video reel** (slider transition, route, stats) ready to post to your **Instagram Story**.

```
SPOT ─► PIN ─► NOTIFY & RSVP ─► START ACTIVITY ─► AFTER PHOTO ─► REEL ─► INSTAGRAM STORY
```

## Features

| Area | What it does |
|---|---|
| **Spot** | Photo → AI detects waste type, volume, hazard and gear list |
| **Clean-Ups** | Map pins by status (open / scheduled / live / done), RSVP, gear checklist |
| **Notifications** | Nearby users are alerted when a Clean-Up is created |
| **Activity** | Route, distance, time, calories, heart rate, steps, bag counter; saved to Apple Health |
| **Dynamic Island** | Live Activity with time, distance, kcal, bags |
| **Ghost camera** | Before photo overlaid to align the After shot |
| **Reel** | 9:16 Before→After slider video with route and stats |
| **Share** | Instagram Stories export, share-sheet fallback |
| **Community** *(planned)* | Feed, kudos, badges, streaks, impact equivalents |

## Tech

Swift 6 · SwiftUI (`@Observable`, iOS 17+) · SwiftData · CoreLocation · MapKit · HealthKit · CoreMotion · Vision · AVFoundation · ActivityKit · UserNotifications/APNs · Supabase (Postgres/PostGIS, Storage, Auth, Edge Functions) · [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Getting started

```bash
brew install xcodegen
xcodegen generate          # generates MyApp.xcodeproj from project.yml
open MyApp.xcodeproj
```

- Set your own signing team in Xcode (a real device is required for camera, HealthKit sensors, background GPS, Live Activities and push).
- Re-run `xcodegen generate` after pulling changes that add files or edit `project.yml`.

## Project layout

```
MyApp/
  Core/DesignSystem/   Dark green theme: Eco.* colors, .eco* fonts, buttons, cards, chips
  Core/                Models, repository protocols, fake data, AppEnvironment (fake vs live switch)
  Features/Activity/   Views/ ViewModels/ Services/  (MVVM: all logic in view models)
  Features/            Camera, Reel, Spot, Map, Feed, Profile, Share (planned)
  Services/            Backend, Notifications (planned)
EcoPlogWidgets/        Live Activity / Dynamic Island
MyAppTests/            View-model unit tests
docs/TEAM_PLAN.md      Product structure, two-person split, milestones, risks
```

## Design system

Dark green is the primary look; the app forces dark mode. Use tokens, never hard-coded colors:

```swift
Text("5.2 km").font(.ecoStat).foregroundStyle(Eco.textPrimary)
Button("Start Activity") { }.buttonStyle(.eco)
EcoStatTile(value: "312", label: "kcal", systemImage: "flame.fill")
```

Open the `Design system` preview in `EcoComponents.swift` to see every component. Fonts: Inter (bundled) for body/labels and Boathouse for headings (add the font files to `MyApp/Resources/Fonts` and `UIAppFonts`; until then headings use the system font).

## Team & roadmap

Two developers: **P1 Activity & Reel** (tracking, HealthKit, Live Activity, ghost camera, video) and **P2 Spot & Community** (AI, map, RSVP, notifications, backend, sharing). Milestones M0 → M4 and the full breakdown are in [`docs/TEAM_PLAN.md`](docs/TEAM_PLAN.md).

## Status

M0 done. Activity flow (record → impact log → summary) works end to end on **fake data** (simulated GPS walk, fake heart rate/steps). Architecture is strict MVVM; switch to live sensors with `AppEnvironment.useFakeData`.
Next: live HealthKit, persistence/history, ghost camera, Reel, Live Activity wiring.
