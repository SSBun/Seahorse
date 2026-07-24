#if os(macOS)
import Foundation
import OSLog

@MainActor
final class ListPerformanceMonitor {
    struct Interval {
        fileprivate let state: OSSignpostIntervalState
        fileprivate let startedAt: TimeInterval
    }

    static let shared = ListPerformanceMonitor()

    private struct ImageLoadKey: Hashable {
        let itemID: UUID
        let role: String
        let resource: String
    }

    private struct PendingImageLoad {
        let startedAt: TimeInterval
        let startedWhileScrolling: Bool
    }

    private let signposter = OSSignposter(
        subsystem: Log.subsystem,
        category: "list-performance"
    )
    private let summaryInterval: TimeInterval = 0.5
    private let slowImageThresholdMs = 50

    private var scrollInterval: Interval?
    private var scrollMode = "unknown"
    private var scrollItemCount = 0
    private var visibleCellCount = 0
    private var appearedCellCount = 0
    private var disappearedCellCount = 0
    private var bookmarkCellCount = 0
    private var imageCellCount = 0
    private var textCellCount = 0
    private var imageLoadSuccessCount = 0
    private var imageLoadFailureCount = 0
    private var imageLoadCancellationCount = 0
    private var slowImageLoadCount = 0
    private var memoryCacheHitCount = 0
    private var diskCacheHitCount = 0
    private var uncachedImageCount = 0
    private var imageLoadTotalMs = 0
    private var imageLoadMaxMs = 0
    private var imageLoadStartedWhileScrollingCount = 0
    private var imageLoadCompletedWhileScrollingCount = 0
    private var scrollSampleCount = 0
    private var scrollDistance = 0.0
    private var maxScrollStep = 0.0
    private var maxScrollGapMs = 0
    private var lastScrollSampleAt: TimeInterval = 0
    private var lastSummaryAt: TimeInterval = 0
    private var pendingImageLoads: [ImageLoadKey: PendingImageLoad] = [:]
    private var imageSummaryTask: Task<Void, Never>?

    private init() {}

    func beginSnapshot(itemCount: Int, reason: String) -> Interval {
        let interval = Interval(
            state: signposter.beginInterval("ListSearchSnapshot"),
            startedAt: Self.now
        )
        Log.info(
            "list_perf snapshot_begin reason=\(reason) items=\(itemCount)",
            category: .performance
        )
        return interval
    }

    func endSnapshot(_ interval: Interval, recordCount: Int, reason: String) {
        signposter.endInterval("ListSearchSnapshot", interval.state)
        Log.info(
            "list_perf snapshot_end reason=\(reason) records=\(recordCount) elapsed_ms=\(Self.elapsedMs(since: interval.startedAt))",
            category: .performance
        )
    }

    func beginFilter(
        requestID: Int,
        reason: String,
        recordCount: Int,
        queryLength: Int,
        selection: String,
        kind: String,
        order: String
    ) -> Interval {
        let interval = Interval(
            state: signposter.beginInterval("ListFilter"),
            startedAt: Self.now
        )
        Log.info(
            "list_perf filter_begin request=\(requestID) reason=\(reason) records=\(recordCount) query_length=\(queryLength) selection=\(selection) kind=\(kind) order=\(order)",
            category: .performance
        )
        return interval
    }

    func endFilter(
        _ interval: Interval,
        requestID: Int,
        resultCount: Int,
        applyMs: Int,
        cancelled: Bool
    ) {
        signposter.endInterval("ListFilter", interval.state)
        Log.info(
            "list_perf filter_end request=\(requestID) results=\(resultCount) apply_ms=\(applyMs) elapsed_ms=\(Self.elapsedMs(since: interval.startedAt)) cancelled=\(cancelled)",
            category: .performance
        )
    }

    func recordCollectionAppeared(itemCount: Int, mode: String) {
        signposter.emitEvent("ListCollectionAppeared")
        Log.info(
            "list_perf collection_appear mode=\(mode) items=\(itemCount)",
            category: .performance
        )
    }

    func recordCollectionChanged(oldCount: Int, newCount: Int, mode: String) {
        signposter.emitEvent("ListCollectionChanged")
        Log.info(
            "list_perf collection_change mode=\(mode) old_items=\(oldCount) new_items=\(newCount)",
            category: .performance
        )
    }

    func recordViewModeChanged(oldMode: String, newMode: String, itemCount: Int) {
        signposter.emitEvent("ListViewModeChanged")
        Log.info(
            "list_perf mode_change old=\(oldMode) new=\(newMode) items=\(itemCount)",
            category: .performance
        )
    }

    func recordScrollPhase(
        previous: String,
        current: String,
        isScrolling: Bool,
        mode: String,
        itemCount: Int
    ) {
        Log.info(
            "list_perf scroll_phase previous=\(previous) current=\(current) mode=\(mode) items=\(itemCount)",
            category: .performance
        )

        if isScrolling, scrollInterval == nil {
            resetScrollCounters(mode: mode, itemCount: itemCount)
            scrollInterval = Interval(
                state: signposter.beginInterval("ListScroll"),
                startedAt: Self.now
            )
            Log.info(
                "list_perf scroll_begin mode=\(mode) items=\(itemCount) visible=\(visibleCellCount)",
                category: .performance
            )
        } else if !isScrolling, let interval = scrollInterval {
            flushScrollSummary(force: true)
            signposter.endInterval("ListScroll", interval.state)
            Log.info(
                "list_perf scroll_end mode=\(scrollMode) items=\(scrollItemCount) visible=\(visibleCellCount) appeared=\(appearedCellCount) disappeared=\(disappearedCellCount) elapsed_ms=\(Self.elapsedMs(since: interval.startedAt))",
                category: .performance
            )
            scrollInterval = nil
        }
    }

    func recordCellAppeared(itemType: String) {
        visibleCellCount += 1
        appearedCellCount += 1
        switch itemType {
        case "bookmark": bookmarkCellCount += 1
        case "image": imageCellCount += 1
        case "text": textCellCount += 1
        default: break
        }
        flushScrollSummary(force: false)
    }

    func recordCellDisappeared() {
        visibleCellCount = max(visibleCellCount - 1, 0)
        disappearedCellCount += 1
        flushScrollSummary(force: false)
    }

    func recordScrollOffset(previous: Double, current: Double) {
        guard scrollInterval != nil else { return }
        let delta = abs(current - previous)
        guard delta > 0 else { return }
        let now = Self.now
        let gapMs = Self.elapsedMs(since: lastScrollSampleAt)
        scrollSampleCount += 1
        scrollDistance += delta
        maxScrollStep = max(maxScrollStep, delta)
        maxScrollGapMs = max(maxScrollGapMs, gapMs)
        lastScrollSampleAt = now

        if scrollSampleCount > 1, gapMs >= 100 {
            signposter.emitEvent("ListScrollGap")
            Log.warning(
                "list_perf scroll_gap gap_ms=\(gapMs) offset_delta=\(Int(delta)) visible=\(visibleCellCount) mode=\(scrollMode)",
                category: .performance
            )
        }
        flushScrollSummary(force: false)
    }

    func beginImageLoad(itemID: UUID, role: String, resource: String) {
        pendingImageLoads[
            ImageLoadKey(itemID: itemID, role: role, resource: resource)
        ] = PendingImageLoad(
            startedAt: Self.now,
            startedWhileScrolling: scrollInterval != nil
        )
    }

    func completeImageLoad(
        itemID: UUID,
        role: String,
        resource: String,
        succeeded: Bool,
        cacheType: String
    ) {
        let key = ImageLoadKey(itemID: itemID, role: role, resource: resource)
        guard let pendingLoad = pendingImageLoads.removeValue(forKey: key) else { return }
        let elapsedMs = Self.elapsedMs(since: pendingLoad.startedAt)

        if succeeded {
            imageLoadSuccessCount += 1
        } else {
            imageLoadFailureCount += 1
        }
        switch cacheType {
        case "memory": memoryCacheHitCount += 1
        case "disk": diskCacheHitCount += 1
        default: uncachedImageCount += 1
        }
        imageLoadTotalMs += elapsedMs
        imageLoadMaxMs = max(imageLoadMaxMs, elapsedMs)
        if pendingLoad.startedWhileScrolling {
            imageLoadStartedWhileScrollingCount += 1
        }
        if scrollInterval != nil {
            imageLoadCompletedWhileScrollingCount += 1
        }
        if elapsedMs >= slowImageThresholdMs {
            slowImageLoadCount += 1
        }
        scheduleImageSummary()
    }

    func cancelImageLoad(itemID: UUID, role: String, resource: String) {
        let key = ImageLoadKey(itemID: itemID, role: role, resource: resource)
        guard pendingImageLoads.removeValue(forKey: key) != nil else { return }
        imageLoadCancellationCount += 1
        scheduleImageSummary()
    }

    func recordStoragePublication(
        property: String,
        oldCount: Int,
        newCount: Int
    ) {
        signposter.emitEvent("ListStoragePublication")
        Log.info(
            "list_perf storage_publish property=\(property) old_count=\(oldCount) new_count=\(newCount) scrolling=\(scrollInterval != nil)",
            category: .performance
        )
    }

    func recordItemsVersion(
        reason: String,
        version: Int,
        totalItems: Int,
        activeItems: Int
    ) {
        signposter.emitEvent("ListItemsVersion")
        Log.info(
            "list_perf items_version reason=\(reason) version=\(version) total_items=\(totalItems) active_items=\(activeItems) scrolling=\(scrollInterval != nil)",
            category: .performance
        )
    }

    private func resetScrollCounters(mode: String, itemCount: Int) {
        scrollMode = mode
        scrollItemCount = itemCount
        appearedCellCount = 0
        disappearedCellCount = 0
        bookmarkCellCount = 0
        imageCellCount = 0
        textCellCount = 0
        scrollSampleCount = 0
        scrollDistance = 0
        maxScrollStep = 0
        maxScrollGapMs = 0
        lastScrollSampleAt = Self.now
        lastSummaryAt = Self.now
    }

    private func flushScrollSummary(force: Bool) {
        guard scrollInterval != nil else { return }
        let now = Self.now
        guard force || now - lastSummaryAt >= summaryInterval else { return }
        signposter.emitEvent("ListScrollSummary")
        Log.info(
            "list_perf scroll_summary mode=\(scrollMode) items=\(scrollItemCount) visible=\(visibleCellCount) appeared=\(appearedCellCount) disappeared=\(disappearedCellCount) cells_bookmark=\(bookmarkCellCount) cells_image=\(imageCellCount) cells_text=\(textCellCount) scroll_samples=\(scrollSampleCount) scroll_distance=\(Int(scrollDistance)) scroll_max_step=\(Int(maxScrollStep)) scroll_max_gap_ms=\(maxScrollGapMs)",
            category: .performance
        )
        lastSummaryAt = now
    }

    private func scheduleImageSummary() {
        guard imageSummaryTask == nil else { return }
        imageSummaryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.flushImageSummary()
        }
    }

    private func flushImageSummary() {
        imageSummaryTask = nil
        let completedImages = imageLoadSuccessCount + imageLoadFailureCount
        let averageImageMs = completedImages == 0 ? 0 : imageLoadTotalMs / completedImages
        signposter.emitEvent("ListImageSummary")
        Log.info(
            "list_perf image_summary success=\(imageLoadSuccessCount) failure=\(imageLoadFailureCount) cancel=\(imageLoadCancellationCount) slow=\(slowImageLoadCount) cache_memory=\(memoryCacheHitCount) cache_disk=\(diskCacheHitCount) cache_none=\(uncachedImageCount) avg_ms=\(averageImageMs) max_ms=\(imageLoadMaxMs) started_while_scrolling=\(imageLoadStartedWhileScrollingCount) completed_while_scrolling=\(imageLoadCompletedWhileScrollingCount)",
            category: .performance
        )
        imageLoadSuccessCount = 0
        imageLoadFailureCount = 0
        imageLoadCancellationCount = 0
        slowImageLoadCount = 0
        memoryCacheHitCount = 0
        diskCacheHitCount = 0
        uncachedImageCount = 0
        imageLoadTotalMs = 0
        imageLoadMaxMs = 0
        imageLoadStartedWhileScrollingCount = 0
        imageLoadCompletedWhileScrollingCount = 0
    }

    private static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func elapsedMs(since start: TimeInterval) -> Int {
        max(Int((now - start) * 1_000), 0)
    }
}
#endif
