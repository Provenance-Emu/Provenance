import Foundation

public enum RoadmapLoader {
    public static func loadAll() -> [RoadmapEpic] {
        guard let url = Bundle.module.url(forResource: "roadmap", withExtension: "json") else {
            #if canImport(PVLogging)
            ELOG("RoadmapLoader: roadmap.json not found in bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([RoadmapEpic].self, from: data)
        } catch {
            #if canImport(PVLogging)
            ELOG("RoadmapLoader: failed to decode roadmap.json — \(error)")
            #endif
            return []
        }
    }
}
