import Foundation

enum UpdateChecker {
    private struct GitHubRelease: Decodable {
        let tag_name: String
    }

    static func check() async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/wontaeyang/hrm/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
        else {
            return nil
        }

        let latestVersion = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

        if compareVersions(latestVersion, isNewerThan: currentVersion) {
            return latestVersion
        }
        return nil
    }

    private static func compareVersions(_ latest: String, isNewerThan current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let count = max(latestParts.count, currentParts.count)
        for i in 0..<count {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
