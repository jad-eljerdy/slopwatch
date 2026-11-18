import Sparkle

final class UpdateUserDriver: SPUStandardUserDriver {
    override func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let original = error as NSError
        var info = original.userInfo
        guard (info[SPUNoUpdateFoundReasonKey] as? NSNumber)?.int32Value == SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue,
              let published = info[SPULatestAppcastItemFoundKey] as? SUAppcastItem,
              let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            super.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
            return
        }
        let sameVersion = installed == published.displayVersionString
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let localLabel = sameVersion ? "\(installed) (build \(build))" : installed
        let releaseLabel = sameVersion ? "\(published.displayVersionString) (build \(published.versionString))" : published.displayVersionString
        info[NSLocalizedDescriptionKey] = "Your installed version is newer."
        info[NSLocalizedRecoverySuggestionErrorKey] = "This Mac runs Slopwatch \(localLabel). The latest published release is \(releaseLabel)."
        let message = NSError(domain: original.domain, code: original.code, userInfo: info)
        super.showUpdateNotFoundWithError(message, acknowledgement: acknowledgement)
    }
}
