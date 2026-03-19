import Foundation

enum VersionComparator {
    static func isNewer(latest: String, current: String) -> Bool {
        let latestComponents = normalize(latest)
        let currentComponents = normalize(current)
        for index in 0..<max(latestComponents.count, currentComponents.count) {
            let latestValue = index < latestComponents.count ? latestComponents[index] : 0
            let currentValue = index < currentComponents.count ? currentComponents[index] : 0
            if latestValue > currentValue { return true }
            if latestValue < currentValue { return false }
        }
        return false
    }

    private static func normalize(_ version: String) -> [Int] {
        version
            .split(whereSeparator: { $0 == "." || $0 == "-" })
            .map { part in
                let digits = part.filter(\.isNumber)
                return Int(digits) ?? 0
            }
    }
}
