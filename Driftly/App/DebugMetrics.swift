import Foundation
import os
#if DEBUG
import MachO
#endif

#if DEBUG
enum DebugMetrics {
    static let renderSignposter = OSSignposter(subsystem: "com.driftly", category: "render")
    static let uiSignposter = OSSignposter(subsystem: "com.driftly", category: "ui")

    private static let log = Logger(subsystem: "com.driftly", category: "perf")
    private static var cacheRebuildCount: UInt = 0
    private static var timerStarted = false

    static func incrementCacheRebuild() {
        cacheRebuildCount &+= 1
    }

    static func startHeartbeat() {
        guard !timerStarted else { return }
        timerStarted = true
        Task.detached { @MainActor in
            let interval: UInt64 = 60_000_000_000 // 60s nanoseconds
            while true {
                try? await Task.sleep(nanoseconds: interval)
                logHeartbeat()
            }
        }
    }

    private static func logHeartbeat() {
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalString: String = {
            switch thermal {
            case .nominal: return "nominal"
            case .fair: return "fair"
            case .serious: return "serious"
            case .critical: return "critical"
            @unknown default: return "unknown"
            }
        }()
        let memoryMB = currentResidentMB()
        log.info("heartbeat: thermal=\(thermalString, privacy: .public) rss=\(memoryMB, format: .fixed(precision: 0))MB cacheRebuilds=\(cacheRebuildCount)")
    }

    private static func currentResidentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024.0 * 1024.0)
    }
}
#else
enum DebugMetrics {
    static func incrementCacheRebuild() {}
    static func startHeartbeat() {}
    static var renderSignposter: OSSignposter { OSSignposter(subsystem: "", category: "") }
    static var uiSignposter: OSSignposter { OSSignposter(subsystem: "", category: "") }
}
#endif
