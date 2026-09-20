import Foundation
import Observation

/// One media page in the post's pager.
struct PostMedia: Identifiable {
    enum Content {
        case photo(URL?)
        case route([Coordinate])
    }
    let id: String
    let title: String
    let content: Content
}

/// Everything the post screen shows about an activity or community post (plain data).
struct PostDetail {
    let activityId: UUID
    let authorName: String
    let isMine: Bool
    let title: String
    let dateText: String
    let stats: [EcoStat]
    let bags: Int
    let media: [PostMedia]
    /// The activity behind the post, used by the share preview.
    let activity: Activity
}

/// Post screen (opened from a notification or a feed card): stats, media, Eco-Boost, comments.
@Observable @MainActor
final class PostDetailViewModel {
    static let maxCommentLength = 300

    private(set) var detail: PostDetail?
    private(set) var comments: [Comment] = []
    private(set) var boost = BoostSummary(count: 0, isBoostedByMe: false, names: [])
    private(set) var isLoading = true
    private(set) var isSending = false
    private(set) var errorMessage: String?
    private(set) var highlightedCommentID: UUID?
    var draft = ""

    let activityId: UUID
    private let highlightTarget: UUID?
    private let user: User
    private let activities: ActivityRepository
    private let feed: FeedService
    private let social: SocialService
    private let now: () -> Date

    init(activityId: UUID, highlightCommentID: UUID? = nil, user: User, activities: ActivityRepository,
         feed: FeedService, social: SocialService, now: @escaping () -> Date = { .now }) {
        self.activityId = activityId
        self.highlightTarget = highlightCommentID
        self.user = user
        self.activities = activities
        self.feed = feed
        self.social = social
        self.now = now
    }

    // MARK: Loading

    func load() async {
        let mine = ((try? await activities.history(userId: user.id)) ?? []).first { $0.id == activityId }
        if let mine {
            detail = makeDetail(from: mine)
        } else if let post = ((try? await feed.recentPosts()) ?? []).first(where: { $0.activityId == activityId }) {
            detail = makeDetail(from: post)
        }
        comments = await social.comments(for: activityId)
        boost = await social.boostSummary(for: activityId, userId: user.id)
        isLoading = false
        if let target = highlightTarget, comments.contains(where: { $0.id == target }) {
            highlightedCommentID = target
        }
    }

    func clearHighlight() { highlightedCommentID = nil }

    var notFound: Bool { !isLoading && detail == nil }

    // MARK: Eco-Boost

    var boostersText: String {
        let names = boost.names
        guard boost.count > 0 else { return "Be the first to give an Eco-Boost" }
        guard !names.isEmpty else { return "\(boost.count) \(boost.count == 1 ? "person" : "people") gave Eco-Boost" }
        let shown = Array(names.prefix(2))
        let others = boost.count - shown.count
        if others <= 0 { return shown.joined(separator: " and ") + " gave Eco-Boost" }
        return shown.joined(separator: ", ") + " and \(others) other\(others == 1 ? "" : "s") gave Eco-Boost"
    }

    var boostButtonTitle: String { boost.isBoostedByMe ? "Boosted" : "Eco-Boost" }

    func toggleBoost() async {
        // Optimistic update, then take the service's answer.
        boost.isBoostedByMe.toggle()
        boost.count = max(0, boost.count + (boost.isBoostedByMe ? 1 : -1))
        boost = await social.toggleBoost(on: activityId, by: user)
    }

    // MARK: Comments

    var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSend: Bool { !trimmedDraft.isEmpty && trimmedDraft.count <= Self.maxCommentLength && !isSending }
    var commentCountText: String { comments.count == 1 ? "1 comment" : "\(comments.count) comments" }

    func sendComment() async {
        guard canSend else { return }
        let text = trimmedDraft
        isSending = true
        errorMessage = nil
        draft = ""
        defer { isSending = false }
        do {
            comments.append(try await social.addComment(text: text, on: activityId, by: user))
        } catch {
            draft = text
            errorMessage = "Couldn't post your comment. Try again."
        }
    }

    func timeText(for comment: Comment) -> String {
        comment.createdAt.formatted(.relative(presentation: .named))
    }

    func isMine(_ comment: Comment) -> Bool { comment.authorId == user.id }

    // MARK: Building the detail

    private func makeDetail(from activity: Activity) -> PostDetail {
        var media: [PostMedia] = []
        let after = activity.afterPhotoURL
        if let before = activity.beforePhotoURL { media.append(PostMedia(id: "before", title: "Before", content: .photo(before))) }
        if let photo = after ?? DemoPhotos.pairedAfter(for: activity.beforePhotoURL) {
            media.append(PostMedia(id: "after", title: "After", content: .photo(photo)))
        }
        if activity.route.count > 1 {
            media.append(PostMedia(id: "route", title: "Route", content: .route(activity.route.map(\.coordinate))))
        }
        if media.isEmpty { media.append(PostMedia(id: "photo", title: "Photo", content: .photo(fallbackPhoto))) }
        return PostDetail(
            activityId: activity.id, authorName: user.name, isMine: true, title: activity.title,
            dateText: activity.startedAt.formatted(date: .abbreviated, time: .shortened),
            stats: [
                EcoStat(label: "Distance", value: String(format: "%.2f km", activity.distance / 1000)),
                EcoStat(label: "Time", value: ActivityViewModel.formatDuration(activity.duration)),
                EcoStat(label: "Bags", value: "\(activity.impactLog.bags)"),
            ],
            bags: activity.impactLog.bags, media: media, activity: activity
        )
    }

    private func makeDetail(from post: FeedPost) -> PostDetail {
        let synthetic = Activity(
            id: post.activityId, userId: post.authorId, cleanUpId: nil,
            startedAt: post.createdAt.addingTimeInterval(-3_000), endedAt: post.createdAt, route: [],
            distance: post.distanceKm * 1000, duration: 3_000, elevation: 0, kcal: post.kcal, avgHR: nil, steps: 0,
            impactLog: ImpactLog(bags: post.bags, kg: Double(post.bags) * 2.2), afterPhotoURL: post.afterPhotoURL,
            reelURL: nil, title: post.cleanUpTitle, kcalIsEstimated: false, healthWorkoutId: nil,
            beforePhotoURL: post.beforePhotoURL
        )
        var media: [PostMedia] = []
        if let before = post.beforePhotoURL { media.append(PostMedia(id: "before", title: "Before", content: .photo(before))) }
        if let after = post.afterPhotoURL { media.append(PostMedia(id: "after", title: "After", content: .photo(after))) }
        if media.isEmpty { media.append(PostMedia(id: "photo", title: "Photo", content: .photo(fallbackPhoto))) }
        return PostDetail(
            activityId: post.activityId, authorName: post.authorName, isMine: post.authorId == user.id,
            title: post.cleanUpTitle, dateText: post.createdAt.formatted(date: .abbreviated, time: .shortened),
            stats: [
                EcoStat(label: "Distance", value: String(format: "%.1f km", post.distanceKm)),
                EcoStat(label: "Bags", value: "\(post.bags)"),
                EcoStat(label: "Energy", value: "\(Int(post.kcal)) kcal"),
            ],
            bags: post.bags, media: media, activity: synthetic
        )
    }

    /// Fake-data fallback so a post never shows an empty box.
    private var fallbackPhoto: URL? {
        DemoPhotos.url(DemoPhotos.crewNames[Int(activityId.uuid.0) % DemoPhotos.crewNames.count])
    }
}
