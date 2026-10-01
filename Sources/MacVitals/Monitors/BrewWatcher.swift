import CoreServices
import Foundation

/// Calls `onChange` once Homebrew has finished changing things: after `brew upgrade`, `install`,
/// or `uninstall` (Cellar, Caskroom) and after `brew update` (the API cache). Waits until the
/// folders have been quiet for a few seconds, since an upgrade touches thousands of files.
final class BrewWatcher {
    private static let quietPeriod: TimeInterval = 5

    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private var pending: DispatchWorkItem?

    init?(onChange: @escaping () -> Void) {
        guard let brew = BrewChecker.brewPath else { return nil }
        let prefix = ((brew as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        let cache = ProcessInfo.processInfo.environment["HOMEBREW_CACHE"]
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches/Homebrew")
        let paths = ["\(prefix)/Cellar", "\(prefix)/Caskroom", "\(cache)/api"]
            .filter { FileManager.default.fileExists(atPath: $0) }
        guard !paths.isEmpty else { return nil }

        self.onChange = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<BrewWatcher>.fromOpaque(info).takeUnretainedValue().changed()
        }
        guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1,
                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
        else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    deinit {
        pending?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    private func changed() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.quietPeriod, execute: work)
    }
}
