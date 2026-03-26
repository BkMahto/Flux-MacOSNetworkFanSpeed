import Combine
import Foundation
import SwiftUI
import Darwin
import IOKit.ps

final class SystemStatsViewModel: ObservableObject {
    // MARK: - Visibility Gating
    @Published var isDashboardVisible: Bool = false {
        didSet { updateMonitoring() }
    }
    @Published var isSettingsVisible: Bool = false {
        didSet { updateMonitoring() }
    }

    // MARK: - Public Metrics (formatted for the UI)
    @Published private(set) var cpuUsageText: String = "-%"
    @Published private(set) var memoryUsageText: String = "-"
    @Published private(set) var swapUsageText: String = "-"
    @Published private(set) var diskFreeText: String = "-"
    @Published private(set) var diskIOText: String = "-"
    @Published private(set) var batteryStatusText: String = "-"

    // MARK: - Polling Interval (seconds)
    @Published var refreshInterval: Double = 1.0 {
        didSet {
            guard refreshInterval > 0 else { return }
            restartTimerIfNeeded()
            restartIOStatIfNeeded()
        }
    }

    // MARK: - Private State
    private var timer: AnyCancellable?
    private var isMonitoring: Bool = false

    // CPU usage delta
    private struct CPUTicks {
        var user: UInt64
        var system: UInt64
        var idle: UInt64
        var nice: UInt64
    }

    private var lastCPUTicks: CPUTicks?

    // iostat process for disk IO
    private var iostatProcess: Process?
    private var iostatStdoutHandle: FileHandle?
    private var iostatReadBuffer: String = ""
    private let iostatQueue = DispatchQueue(label: "SystemStatsViewModel.iostatQueue")

    // Throttle expensive/slow updates.
    private var lastSwapUpdateDate: Date?
    private var lastSwapUsageText: String = "-"
    private var lastBatteryUpdateDate: Date?
    private var lastBatteryStatusText: String = "-"

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring Start/Stop
    private func updateMonitoring() {
        // System metrics UI lives inside `SettingsView`, so we only poll while that view is visible.
        // (Even in mini dashboard mode, the window may be visible but the system metrics section is hidden.)
        let shouldMonitor = isSettingsVisible
        if shouldMonitor == isMonitoring { return }
        isMonitoring = shouldMonitor
        if shouldMonitor {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        restartTimer()
        restartIOStat()
        updateAllOnce()
    }

    private func stopMonitoring() {
        timer?.cancel()
        timer = nil
        stopIOStat()
    }

    private func restartTimerIfNeeded() {
        guard isMonitoring else { return }
        restartTimer()
    }

    private func restartIOStatIfNeeded() {
        guard isMonitoring else { return }
        restartIOStat()
    }

    private func restartTimer() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAllOnce()
            }
    }

    private func updateAllOnce() {
        updateCPUUsage()
        updateMemoryAndSwap()
        updateDiskFree()
        updateBattery()
    }

    // MARK: - CPU Usage
    private func updateCPUUsage() {
        guard let current = fetchCPUTicks() else { return }
        defer { lastCPUTicks = current }

        guard let last = lastCPUTicks else { return }

        let userDiff = current.user - last.user
        let systemDiff = current.system - last.system
        let idleDiff = current.idle - last.idle
        let niceDiff = current.nice - last.nice

        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return }

        let idleRatio = Double(idleDiff) / Double(totalDiff)
        let usageRatio = 1.0 - idleRatio
        let percent = usageRatio * 100.0

        cpuUsageText = String(format: "%.0f%%", percent)
    }

    private func fetchCPUTicks() -> CPUTicks? {
        // Uses Mach API so we can compute usage without spawning external processes.
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

        // host_processor_info allocates memory; free it.
        defer {
            _ = vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo))
        }

        // PROCESSOR_CPU_LOAD_INFO produces 4 integers per CPU: user, system, idle, nice.
        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0

        let cpuCount = Int(processorCount)
        guard cpuCount > 0 else { return nil }

        for i in 0..<cpuCount {
            let offset = i * 4
            user += UInt64(cpuInfo[offset])
            system += UInt64(cpuInfo[offset + 1])
            idle += UInt64(cpuInfo[offset + 2])
            nice += UInt64(cpuInfo[offset + 3])
        }

        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return CPUTicks(user: user, system: system, idle: idle, nice: nice)
    }

    // MARK: - Memory + Swap
    private func updateMemoryAndSwap() {
        let totalBytes = totalPhysicalMemoryBytes()
        guard totalBytes > 0 else { return }

        var freeBytes: UInt64 = 0
        var inactiveBytes: UInt64 = 0
        if let vm = fetchVMStatistics() {
            // Keep it simple: free + inactive as "effectively available".
            freeBytes = vm.freePages * UInt64(vm.pageSizeBytes)
            inactiveBytes = vm.inactivePages * UInt64(vm.pageSizeBytes)
        }

        let availableBytes = freeBytes + inactiveBytes
        let usedBytes = totalBytes > availableBytes ? (totalBytes - availableBytes) : 0
        let usedText = formatBytes(usedBytes)
        let totalText = formatBytes(totalBytes)

        memoryUsageText = "\(usedText) / \(totalText)"

        // Swap usage is fetched via `sysctl vm.swapusage` (text output).
        // Throttle it to avoid extra work every timer tick.
        if let last = lastSwapUpdateDate, Date().timeIntervalSince(last) < 5.0 {
            swapUsageText = lastSwapUsageText
        } else {
            if let swapText = fetchSwapUsageText() {
                lastSwapUpdateDate = Date()
                lastSwapUsageText = swapText
                swapUsageText = swapText
            } else {
                swapUsageText = "N/A"
            }
        }
    }

    private struct VMStatisticsSimple {
        let pageSizeBytes: UInt32
        let freePages: UInt64
        let inactivePages: UInt64
    }

    private func fetchVMStatistics() -> VMStatisticsSimple? {
        let hostPort = mach_host_self()

        var pageSize: vm_size_t = 0
        let pageSizeResult = withUnsafeMutablePointer(to: &pageSize) { pageSizePtr in
            host_page_size(hostPort, pageSizePtr)
        }
        guard pageSizeResult == KERN_SUCCESS else { return nil }

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { vmStatsPtr in
            vmStatsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return VMStatisticsSimple(
            pageSizeBytes: UInt32(pageSize),
            freePages: UInt64(vmStats.free_count),
            inactivePages: UInt64(vmStats.inactive_count)
        )
    }

    private func totalPhysicalMemoryBytes() -> UInt64 {
        var size: Int = 0
        let value = sysctlbyname("hw.memsize", nil, &size, nil, 0)
        guard value == 0 else { return 0 }

        var memsize: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memsize, &len, nil, 0) == 0 {
            return memsize
        }
        return 0
    }

    private func fetchSwapUsageText() -> String? {
        // Example:
        // vm.swapusage: total = 7168.00M  used = 6294.75M  free = 873.25M  (encrypted)
        guard let output = runCommand(executable: "/usr/sbin/sysctl", arguments: ["vm.swapusage"]) else {
            return nil
        }

        let regexTotal = try? NSRegularExpression(pattern: #"total\s*=\s*([0-9.]+)\s*([KMGTP]?)(?:B)?\s*"#)
        let regexUsed = try? NSRegularExpression(pattern: #"used\s*=\s*([0-9.]+)\s*([KMGTP]?)(?:B)?\s*"#)

        guard let totalMatch = regexTotal?.firstMatch(in: output, range: NSRange(output.startIndex..<output.endIndex, in: output)),
              let usedMatch = regexUsed?.firstMatch(in: output, range: NSRange(output.startIndex..<output.endIndex, in: output))
        else { return nil }

        let totalValue = doubleFrom(output, totalMatch, group: 1) ?? 0
        let totalUnit = stringFrom(output, totalMatch, group: 2) ?? "M"
        let usedValue = doubleFrom(output, usedMatch, group: 1) ?? 0
        let usedUnit = stringFrom(output, usedMatch, group: 2) ?? "M"

        let totalBytes = bytesFrom(value: totalValue, unit: totalUnit)
        let usedBytes = bytesFrom(value: usedValue, unit: usedUnit)
        return "\(formatBytes(usedBytes)) / \(formatBytes(totalBytes))"
    }

    private func doubleFrom(_ text: String, _ match: NSTextCheckingResult, group: Int) -> Double? {
        guard match.numberOfRanges > group else { return nil }
        let range = match.range(at: group)
        guard let swiftRange = Range(range, in: text) else { return nil }
        return Double(String(text[swiftRange]))
    }

    private func stringFrom(_ text: String, _ match: NSTextCheckingResult, group: Int) -> String? {
        guard match.numberOfRanges > group else { return nil }
        let range = match.range(at: group)
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func bytesFrom(value: Double, unit: String) -> UInt64 {
        let multiplier: Double
        switch unit.uppercased() {
        case "K": multiplier = 1024.0
        case "M", "": multiplier = 1024.0 * 1024.0
        case "G": multiplier = 1024.0 * 1024.0 * 1024.0
        case "T": multiplier = 1024.0 * 1024.0 * 1024.0 * 1024.0
        default: multiplier = 1024.0 * 1024.0
        }
        return UInt64(value * multiplier)
    }

    // MARK: - Disk Free
    private func updateDiskFree() {
        do {
            // "/" is usually the main volume; if you prefer, you can target the active system volume.
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? NSNumber,
               let free = attrs[.systemFreeSize] as? NSNumber {
                diskFreeText = "\(formatBytes(free.uint64Value)) / \(formatBytes(total.uint64Value))"
            }
        } catch {
            diskFreeText = "N/A"
        }
    }

    // MARK: - Disk IO via iostat
    private func restartIOStat() {
        stopIOStat()
        startIOStat()
    }

    private func startIOStat() {
        guard iostatProcess == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        // -d: disk stats only (avoids mixing CPU load columns)
        proc.arguments = ["-d", "\(refreshInterval)"]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        iostatProcess = proc
        iostatStdoutHandle = pipe.fileHandleForReading
        iostatReadBuffer = ""

        iostatStdoutHandle?.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            self.iostatQueue.async {
                self.iostatReadBuffer.append(chunk)
                self.processIostatBufferLines()
            }
        }

        do {
            try proc.run()
        } catch {
            diskIOText = "N/A"
        }
    }

    private func processIostatBufferLines() {
        // Break by newline; keep the tail for next chunk.
        let parts = iostatReadBuffer.components(separatedBy: "\n")
        guard !parts.isEmpty else { return }

        let completeLines = parts.dropLast()
        iostatReadBuffer = parts.last ?? ""

        for line in completeLines {
            parseDiskIOLine(line)
        }
    }

    private func parseDiskIOLine(_ line: String) {
        // Data rows are mostly numeric columns. We sum all MB/s columns.
        // Expected pattern with `iostat -d`: 3 values per disk: KB/t, tps, MB/s
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first.map({ $0.isNumber }) == true else { return }

        let numbers = extractDoubles(trimmed)
        guard numbers.count >= 3, numbers.count % 3 == 0 else { return }

        var sumMBs: Double = 0
        for diskIndex in 0..<(numbers.count / 3) {
            let mbValue = numbers[diskIndex * 3 + 2]
            sumMBs += mbValue
        }

        DispatchQueue.main.async { [weak self] in
            self?.diskIOText = String(format: "%.1f MB/s", sumMBs)
        }
    }

    private func extractDoubles(_ line: String) -> [Double] {
        // Extract ints/floats with a small regex.
        let regex = try? NSRegularExpression(pattern: #"[-+]?\d*\.?\d+"#)
        guard let regex else { return [] }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: range)
        return matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: line) else { return nil }
            return Double(String(line[swiftRange]))
        }
    }

    private func stopIOStat() {
        iostatStdoutHandle?.readabilityHandler = nil
        iostatStdoutHandle = nil

        iostatProcess?.terminate()
        iostatProcess = nil
    }

    // MARK: - Battery
    private func updateBattery() {
        if let last = lastBatteryUpdateDate, Date().timeIntervalSince(last) < 10.0 {
            batteryStatusText = lastBatteryStatusText
            return
        }

        guard let infoText = fetchBatteryText() else {
            batteryStatusText = "N/A"
            return
        }

        lastBatteryUpdateDate = Date()
        lastBatteryStatusText = infoText
        batteryStatusText = infoText
    }

    private func fetchBatteryText() -> String? {
        // Use IOKit when available (no external command).
        // Note: on systems without a battery, this will return nil.
        guard let infoU = IOPSCopyPowerSourcesInfo() else { return nil }
        let info = infoU.takeRetainedValue()

        guard let listU = IOPSCopyPowerSourcesList(info) else { return nil }
        let list = listU.takeRetainedValue()

        let count = CFArrayGetCount(list)
        if count == 0 { return nil }

        for i in 0..<count {
            let ps = CFArrayGetValueAtIndex(list, i)
            let psAny = unsafeBitCast(ps, to: CFTypeRef.self)

            guard let descU = IOPSGetPowerSourceDescription(info, psAny) else { continue }
            let desc = descU.takeRetainedValue() as NSDictionary

            let current = (desc[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue
            let max = (desc[kIOPSMaxCapacityKey] as? NSNumber)?.intValue
            let stateAny = desc[kIOPSPowerSourceStateKey]
            let stateStr = stateAny.map { String(describing: $0) }.flatMap { $0.isEmpty ? nil : $0 } ?? ""

            guard let cur = current, let m = max, m > 0 else { continue }
            let percent = Int(Double(cur) / Double(m) * 100.0)

            let isCharging = stateStr.lowercased().contains("charging")

            var text = "\(percent)%"
            text += isCharging ? " (Charging)" : " (Discharging)"
            return text
        }

        return nil
    }

    // MARK: - Formatting
    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        let kb = b / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        let tb = gb / 1024.0

        if tb >= 1.0 { return String(format: "%.2f TB", tb) }
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        if mb >= 1.0 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f B", b)
    }

    // MARK: - Command Helper
    private func runCommand(executable: String, arguments: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
        } catch {
            return nil
        }

        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
    }
}

