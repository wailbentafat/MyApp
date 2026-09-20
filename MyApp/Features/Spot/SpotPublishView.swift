import SwiftUI

struct SpotPublishView: View {
    var image: UIImage?
    var result: ScannerResult
    var isPublishing: Bool
    var onPublish: (_ title: String, _ startsAt: Date?, _ capacity: Int?) async -> Void

    @State private var title: String = ""
    @State private var scheduleNow = true
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var capacity = 6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                if image != nil {
                    EcoPhoto(image: image, height: 180, cornerRadius: Eco.Radius.card)
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Title")
                    TextField("Clean-Up title", text: $title)
                        .textFieldStyle(EcoTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "When")
                    Picker("When", selection: $scheduleNow) {
                        Text("Now").tag(true)
                        Text("Schedule").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if !scheduleNow {
                        DatePicker("Starts", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .tint(Eco.primary)
                    }
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Capacity")
                    Stepper("Up to \(capacity) people", value: $capacity, in: 2...30, step: 1)
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textPrimary)
                }

                VStack(alignment: .leading, spacing: Eco.Space.s) {
                    EcoSectionHeader(title: "Summary")
                    HStack(spacing: Eco.Space.s) {
                        ForEach(result.wasteTypes) { type in
                            EcoChip(title: type.label, systemImage: type.systemImage)
                        }
                    }
                    Text("~\(result.estimatedBags) bags · \(result.severity.label.lowercased()) severity · \(result.gear.count) gear items")
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                }

                Button {
                    Task {
                        await onPublish(
                            title.isEmpty ? defaultTitle : title,
                            scheduleNow ? nil : scheduledDate,
                            capacity
                        )
                    }
                } label: {
                    if isPublishing {
                        ProgressView().tint(Eco.onPrimary)
                    } else {
                        Text("Publish Clean-Up")
                    }
                }
                .buttonStyle(.eco)
                .disabled(isPublishing)
            }
            .padding(Eco.Space.l)
        }
        .ecoScreenBackground()
        .onAppear {
            if title.isEmpty { title = defaultTitle }
        }
    }

    private var defaultTitle: String {
        guard let first = result.wasteTypes.first else { return "Clean-Up" }
        return "\(first.label) clean-up"
    }
}

#Preview {
    NavigationStack {
        SpotPublishView(
            image: DemoPhoto.image,
            result: ScannerResult(
                wasteTypes: [.plastic, .glass], severity: .medium, estimatedBags: 3,
                gear: Fixtures.gear(for: [.plastic, .glass]), hazard: .none, peopleNeeded: 2,
                confidence: 0.9, modelVersion: "ecoplog-vision-fake-v1"
            ),
            isPublishing: false,
            onPublish: { _, _, _ in }
        )
    }
    .ecoTheme()
}
