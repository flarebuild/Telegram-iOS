import Foundation
import MonotonicTime

public struct MonotonicTimestamp: Codable, Equatable {
    public var bootTimestap: Int32
    public var uptime: Int32

    public init(bootTimestap: Int32, uptime: Int32) {
        self.bootTimestap = bootTimestap
        self.uptime = uptime
    }
}

public struct UnlockAttempts: Codable, Equatable {
    public var count: Int32
    public var wallClockTimestamp: Int32

    public init(count: Int32, wallClockTimestamp: Int32) {
        self.count = count
        self.wallClockTimestamp = wallClockTimestamp
    }
}

public struct LockState: Codable, Equatable {
    public var isManuallyLocked: Bool
    public var autolockTimeout: Int32?
    public var unlockAttemts: UnlockAttempts?
    public var applicationActivityTimestamp: MonotonicTimestamp?

    public init(isManuallyLocked: Bool = false, autolockTimeout: Int32? = nil, unlockAttemts: UnlockAttempts? = nil, applicationActivityTimestamp: MonotonicTimestamp? = nil) {
        self.isManuallyLocked = isManuallyLocked
        self.autolockTimeout = autolockTimeout
        self.unlockAttemts = unlockAttemts
        self.applicationActivityTimestamp = applicationActivityTimestamp
    }
}

public func appLockStatePath(rootPath: String) -> String {
    return rootPath + "/lockState.json"
}

public func isAppLocked(state: LockState) -> Bool {
    if state.isManuallyLocked {
        return true
    } else if let autolockTimeout = state.autolockTimeout {
        var bootTimestamp: Int32 = 0
        let uptime = getDeviceUptimeSeconds(&bootTimestamp)
        let timestamp = MonotonicTimestamp(bootTimestap: bootTimestamp, uptime: uptime)
        
        if let applicationActivityTimestamp = state.applicationActivityTimestamp {
            if timestamp.bootTimestap != applicationActivityTimestamp.bootTimestap {
                return true
            }
            if timestamp.uptime >= applicationActivityTimestamp.uptime + autolockTimeout {
                return true
            }
        } else {
            return true
        }
    }
    return false
}