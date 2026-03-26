import Combine
import Foundation
import SwiftUI
import Darwin

final class CPUCoreUsageViewModel: ObservableObject {
    @Published private(set) var perCoreUsage: [Double] = [] // 0...1, per logical CPU

    var refreshInterval: Double = 1.0 {
        didSet {
            guard refreshInterval > 0 else { return }
            if isRunning {
                restart()
            }
        }
    }

    private var timer: AnyCancellable?
    private var isRunning: Bool = false

    private struct CoreTicks {
        var user: UInt64
        var system: UInt64
        var idle: UInt64
        var nice: UInt64
    }

    private var lastPerCoreTicks: [CoreTicks] = []

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastPerCoreTicks = []
        tick() // prime
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        lastPerCoreTicks = []
    }

    private func restart() {
        stop()
        start()
    }

    func usagePercentText(coreIndex: Int) -> String? {
        guard coreIndex >= 0, coreIndex < perCoreUsage.count else { return nil }
        let pct = perCoreUsage[coreIndex] * 100.0
        return String(format: "%.0f%%", pct)
    }

    private func tick() {
        guard let current = fetchPerCoreTicks() else { return }

        guard !lastPerCoreTicks.isEmpty, lastPerCoreTicks.count == current.count else {
            lastPerCoreTicks = current
            perCoreUsage = Array(repeating: 0, count: current.count)
            return
        }

        var usage: [Double] = []
        usage.reserveCapacity(current.count)

        for i in 0..<current.count {
            let last = lastPerCoreTicks[i]
            let now = current[i]

            let userDiff = now.user - last.user
            let systemDiff = now.system - last.system
            let idleDiff = now.idle - last.idle
            let niceDiff = now.nice - last.nice

            let total = userDiff + systemDiff + idleDiff + niceDiff
            if total == 0 {
                usage.append(0)
                continue
            }

            let used = Double(userDiff + systemDiff + niceDiff) / Double(total)
            usage.append(max(0, min(1, used)))
        }

        lastPerCoreTicks = current
        perCoreUsage = usage
    }

    private func fetchPerCoreTicks() -> [CoreTicks]? {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let host = mach_host_self()
        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return nil }

        defer {
            _ = vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo))
        }

        let cpuCount = Int(processorCount)
        guard cpuCount > 0 else { return nil }

        var cores: [CoreTicks] = []
        cores.reserveCapacity(cpuCount)

        for i in 0..<cpuCount {
            let offset = i * 4
            let user = UInt64(cpuInfo[offset])
            let system = UInt64(cpuInfo[offset + 1])
            let idle = UInt64(cpuInfo[offset + 2])
            let nice = UInt64(cpuInfo[offset + 3])
            cores.append(CoreTicks(user: user, system: system, idle: idle, nice: nice))
        }

        return cores
    }
}

