import SwiftUI

/// Sheet opened by the center Record button.
struct RecordSheetView: View {
    enum Choice { case spot, freeActivity, cleanUp(CleanUp) }

    var onChoose: (Choice) -> Void

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.appSession) private var appSession
    @State private var viewModel: RecordSheetViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.l) {
                Text("What are you up to?")
                    .font(.ecoDisplaySmall)
                    .foregroundStyle(Eco.textPrimary)

                optionCard(
                    title: "Spot pollution",
                    subtitle: "Photograph a polluted place. AI lists the waste and the gear, and pins a Clean-Up.",
                    systemImage: "camera.viewfinder"
                ) { onChoose(.spot) }

                optionCard(
                    title: "Start an activity",
                    subtitle: "Track a walk or run, log what you collect, and share the Before/After.",
                    systemImage: "figure.walk"
                ) { onChoose(.freeActivity) }

                if let viewModel, !viewModel.myCleanUps.isEmpty {
                    Text("Your Clean-Ups")
                        .font(.ecoHeadlineSmall)
                        .foregroundStyle(Eco.textPrimary)
                        .padding(.top, Eco.Space.s)
                    ForEach(viewModel.myCleanUps) { cleanUp in
                        Button { onChoose(.cleanUp(cleanUp)) } label: {
                            HStack(spacing: Eco.Space.m) {
                                CleanUpPhoto(cleanUp: cleanUp, height: 56)
                                    .frame(width: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cleanUp.title).font(.ecoTitleMedium).foregroundStyle(Eco.textPrimary)
                                    Text(viewModel.timeText(for: cleanUp)).font(.ecoBodySmall).foregroundStyle(Eco.textSecondary)
                                }
                                Spacer()
                                EcoSymbol("play.fill", size: 16).foregroundStyle(Eco.onButton).frame(width: 36, height: 36).background(Eco.buttonFill, in: Circle())
                            }
                            .padding(Eco.Space.m)
                            .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.field))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Eco.Space.l)
        }
        .task {
            guard viewModel == nil, let user = appSession.currentUser else { return }
            let model = RecordSheetViewModel(userId: user.id, repository: cleanUpRepository)
            viewModel = model
            await model.load()
        }
    }

    private func optionCard(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Eco.Space.l) {
                EcoSymbol(systemImage, size: 28)
                    .foregroundStyle(Eco.onButton)
                    .frame(width: 60, height: 60)
                    .background(Eco.buttonFill, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.ecoHeadlineSmall).foregroundStyle(Eco.textPrimary)
                    Text(subtitle).font(.ecoBodySmall).foregroundStyle(Eco.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Eco.Space.l)
            .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
