# EcoPlog: Product Requirements & Architecture Document

---

## 1. Executive Summary & Core Architecture

* **Core Mission:** Gamify eco-action through fitness tracking, social proof, AI-driven waste detection, and verifiable community impact.
* **Target Audience:** Ploggers (joggers/walkers who pick up litter), volunteer cleanup groups, outdoor enthusiasts, running clubs, and climate-conscious communities.
* **Platform & Stack Alignment:** Native iOS application developed in **Swift** and **SwiftUI**, heavily utilizing native Apple frameworks (**HealthKit**, **CoreLocation**, **MapKit**, **Vision**, **CoreML**, **AVFoundation**, and **ActivityKit**).

---

## 2. Core Feature Breakdown

### A. Activity Tracking & Eco-Telemetry
* **Session Recording:** Initiate a "Plog" or "Clean Walk" workout. Tracks polyline route, total elevation, duration, speed, and total distance in real time via `CoreLocation` and `MapKit`.
* **Health Metrics Engine:** Native `HealthKit` integration tracking active energy burned ($\text{kcal}$), average heart rate, distance, and total step count during an active workout session.
* **Before / After Proof Capture:** Mid-activity camera workflow featuring alignment guides and ghosted overlays to ensure precise camera positioning for Before vs. After media capture.
* **Impact Metrics Log:** Streamlined post-activity workflow allowing users to log collected volume (e.g., *2 bags, 5 kg, 12 plastic bottles*).

### B. AI-Powered Environmental Scanner
* **Pollution Spotting:** One-tap camera capture to flag a polluted location while on a run or walk.
* **On-Device AI Auto-Tagging:** Utilizes `CoreML` and `Vision` frameworks to classify waste types (plastics, bulk items, hazardous debris) and auto-estimate required gear (e.g., *heavy-duty gloves, 3x 50L bags, trash picker*).
* **Automated Event Generation:** Automatically converts the analyzed photo and geotag into a public "Clean-Up Beacon" on the community map for individual or group resolution.

### C. Shareable Social Badges & Media Engine
* **Dynamic Social Cards:** Renders styled summary graphics using SwiftUI’s `ImageRenderer` containing map polylines, workout stats, HealthKit metrics, and side-by-side site photos.
* **Before/After Video Animation Generator:** Generates a dynamic video clip featuring a smooth transition (wipe, fade, or 3D slider effect) between the "Before" and "After" photos, complete with overlaid telemetry metrics (distance, time, trash volume).
* **Direct Social Deep-Linking:** Export system using `UIActivityViewController` and custom URL schemes (`instagram-stories://`, `tiktok://`) to push generated images and animated MP4 video files directly to social media stories with branded stickers and hashtags.

### D. Community & Geo-Discovery Hub
* **Interactive Map Feed:** Native SwiftUI `Map` view displaying active ploggers, historical clean zones (heatmaps), and active pollution beacons needing volunteers.
* **Group Expeditions:** Create and discover localized cleanup events with live RSVP counts, meeting location pins, and integrated group chat.
* **Community Feed:** Strava-style social feed featuring user activities, kudos ("Eco-Boosts"), comments, and downloadable routes.

---

## 3. Proposed Value-Add Features

### A. Interactive Heatmaps & "Cleaned Territory"
* **Territory Control:** Visual map overlays highlighting neighborhoods or trail sectors based on recent community cleanup frequency.
* **Regeneration Decay:** Sectors slowly decay back to "Needs Attention" status over time if no activities are recorded, encouraging recurring local runs.

### B. Before/After Dynamic Reel Builder
* **Cinematic Export:** Combines recorded GPS route animations with the before-and-after photo video transition into a shareable 15-second vertical video reel (9:16) optimized for Instagram Reels, TikTok, and YouTube Shorts.

### C. Corporate & Local Council Challenges
* **Leaderboards:** Monthly neighborhood, university, or corporate leaderboards tracking total volume cleared, hours spent, and kilometers covered.
* **Sponsorship Rewards:** Partnerships with eco-friendly brands to unlock digital badges, discount codes, or tree-planting contributions upon hitting activity milestones.

---

## 4. Key Apple Frameworks & Native Integrations

| Feature Component | iOS Framework / Technology | Technical Implementation Purpose |
| :--- | :--- | :--- |
| **Workout & Energy** | `HealthKit` | Reads active energy burned, heart rate, and step count; writes and syncs workouts as `HKWorkout` (*Outdoor Walking / Running*). |
| **Route & Mapping** | `CoreLocation` & `MapKit` | Tracks background GPS coordinates, renders polyline paths, and manages interactive map annotations and sector overlays. |
| **On-Device AI** | `Vision` & `CoreML` | Runs image classification models locally to identify waste categories, estimate volume, and recommend equipment needed. |
| **Video Engine** | `AVFoundation` | Processes, renders, and exports dynamic animated transition videos (MP4) from before/after photos and telemetry overlays. |
| **Card Generation** | SwiftUI `ImageRenderer` | Converts native SwiftUI card views with metrics and maps into high-resolution PNG images for instant social sharing. |
| **Lock Screen / Island** | `ActivityKit` (Live Activities) | Displays real-time workout stats, route duration, heart rate, and collected bag count on the Dynamic Island and Lock Screen. |