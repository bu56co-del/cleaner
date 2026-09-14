import SwiftUI
import Charts
import PawlyCore

struct HealthView: View {
    @Bindable var store: AppStore
    @Bindable var mole: MoleStore
    @State private var showDetails = false
    @State private var showRawStatus = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack {
                    PageHeading(title: store.t("健康狀態", "Health"),
                                subtitle: mole.health.map { $0["hardware"]["model"].display + " · " + $0["hardware"]["cpu_model"].display } ?? store.t("正在讀取真實系統資訊。", "Reading live system information."))
                    Spacer()
                    Button { if mole.watching { mole.stopHealth() } else { mole.startHealth() } } label: {
                        Label(store.t(mole.watching ? "暫停" : "繼續", mole.watching ? "Pause" : "Resume"), systemImage: mole.watching ? "pause" : "play")
                    }.buttonStyle(PawButtonStyle(prominent: false))
                }
                if let error = mole.healthError { InlineError(text: error) }
                if let health = mole.health {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(store.t("Mole 健康評分", "Mole health score"), systemImage: "heart.fill").foregroundStyle(Palette.sage)
                            Text(health["hardware"]["model"].string?.isEmpty == false ? health["health_score"].display : "—").font(.system(size: 46, weight: .bold, design: .rounded))
                            Text(health["hardware"]["model"].string?.isEmpty == false ? health["health_score_msg"].display : store.t("正在補齊硬件資料…", "Collecting hardware details…")).font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Text(store.t("引擎根據目前負載估算；不是硬件診斷。", "An estimate of current system pressure, not a hardware diagnosis."))
                                .font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).pawCard()
                        trend(title: "CPU", value: health["cpu"]["usage"].number, values: mole.cpuHistory, color: Palette.coral)
                        trend(title: store.t("記憶體", "Memory"), value: health["memory"]["used_percent"].number, values: mole.memoryHistory, color: Palette.lavender)
                    }
                    HStack {
                        Label(mole.watching ? store.t("每 2 秒更新", "Updates every 2 seconds") : store.t("已暫停更新", "Updates paused"), systemImage: mole.watching ? "circle.fill" : "pause.circle")
                        Spacer()
                        if let date = mole.healthReceivedAt { Text(date, style: .time) }
                        Text(store.t("感應器未提供的值以 — 顯示", "Unavailable sensors show —"))
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                    if health["hardware"]["model"].string?.isEmpty == false {
                    DisclosureGroup(store.t("CPU、記憶體、磁碟及感應器詳情", "CPU, memory, disk & sensor details"), isExpanded: $showDetails) {
                    if showDetails {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 15) {
                        healthCard(store.t("處理器", "Processor"), "cpu", health["cpu"], icon: "cpu")
                        healthCard(store.t("記憶體與交換空間", "Memory & swap"), "memory", health["memory"], icon: "memorychip")
                        healthCard(store.t("磁碟", "Disks"), "disks", health["disks"], icon: "internaldrive")
                        healthCard(store.t("磁碟讀寫", "Disk activity"), "disk_io", health["disk_io"], icon: "arrow.left.arrow.right")
                        healthCard(store.t("網絡", "Network"), "network", health["network"], icon: "network")
                        healthCard(store.t("電池", "Battery"), "batteries", health["batteries"], icon: "battery.100percent")
                        healthCard(store.t("溫度與電力", "Thermals & power"), "thermal", health["thermal"], icon: "thermometer.medium")
                        healthCard(store.t("圖像處理器", "Graphics"), "gpu", health["gpu"], icon: "display")
                    }
                    }
                    }.padding(16).pawCard()
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label(store.t("目前使用資源最多的程序", "Top processes"), systemImage: "list.bullet.rectangle").font(.system(size: 16, weight: .semibold, design: .rounded))
                        if health["process_stale"].bool == true { Text(store.t("程序資料正在更新；以下為上次讀取結果。", "Refreshing processes; showing the previous sample.")).foregroundStyle(Palette.coral) }
                        HStack { Text(store.t("程序", "Process")); Spacer(); Text("CPU").frame(width: 70, alignment: .trailing); Text(store.t("記憶體", "Memory")).frame(width: 95, alignment: .trailing) }.foregroundStyle(Palette.muted)
                        ForEach(Array(health["top_processes"].array.enumerated()), id: \.offset) { _, process in
                            HStack {
                                Text(process["name"].display).lineLimit(1)
                                Text("#" + process["pid"].display).foregroundStyle(Palette.muted).font(.system(size: 10))
                                Spacer()
                                Text(percent(process["cpu"].number)).monospacedDigit().frame(width: 70, alignment: .trailing)
                                Text(process["memory_bytes"].number.map { FileSize.string(Int64($0)) } ?? percent(process["memory"].number)).monospacedDigit().frame(width: 95, alignment: .trailing)
                            }
                            Divider()
                        }
                    }.font(.system(size: 12)).padding(20).pawCard()
                    DisclosureGroup(store.t("完整狀態", "Full status"), isExpanded: $showRawStatus) {
                        if showRawStatus {
                        MetricDetails(value: health, zh: store.language == "zh").padding(.top, 12)
                        }
                    }.padding(20).pawCard()
                } else {
                    VStack(spacing: 18) {
                        ProgressView(); Text(store.t("小貓正在量度心跳…", "Taking your Mac's pulse…"))
                    }.frame(maxWidth: .infinity).padding(70)
                }
            }.padding(28)
        }.task { mole.startHealth() }.onDisappear { mole.stopHealth() }
    }
    private func percent(_ value: Double?) -> String { value.map { String(format: "%.1f%%", $0) } ?? "—" }
    private func trend(title: String, value: Double?, values: [Double], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).foregroundStyle(Palette.muted)
            Text(percent(value)).font(.system(size: 31, weight: .semibold, design: .rounded)).foregroundStyle(color)
            Chart(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Time", index), y: .value("Usage", value)).foregroundStyle(color.opacity(0.12))
                LineMark(x: .value("Time", index), y: .value("Usage", value)).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
            }.chartYScale(domain: 0...100).chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 58)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).pawCard()
    }
    private func healthCard(_ title: String, _ key: String, _ value: JSONValue, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Palette.sage)
            MetricDetails(value: value, zh: store.language == "zh", context: key)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).pawCard()
    }
}

struct MetricDetails: View {
    let value: JSONValue
    var zh: Bool
    var context = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch value {
            case .object(let object):
                ForEach(object.keys.sorted(), id: \.self) { key in
                    if let child = object[key] {
                        if case .object = child {
                            DisclosureGroup(label(key)) { MetricDetails(value: child, zh: zh, context: key) }
                        } else if case .array = child {
                            DisclosureGroup(label(key) + " (\(child.array.count))") { MetricDetails(value: child, zh: zh, context: key) }
                        } else {
                            HStack(alignment: .top) {
                                Text(label(key)).foregroundStyle(Palette.muted)
                                Spacer(minLength: 10)
                                Text(formatted(child, key: key)).multilineTextAlignment(.trailing).textSelection(.enabled).monospacedDigit()
                            }
                        }
                    }
                }
            case .array(let values):
                if values.isEmpty { Text(zh ? "未提供／不適用" : "Unavailable / not applicable").foregroundStyle(Palette.muted) }
                ForEach(Array(values.enumerated()), id: \.offset) { index, child in
                    if index > 0 { Divider().padding(.vertical, 4) }
                    MetricDetails(value: child, zh: zh, context: context)
                }
            default: Text(value.display)
            }
        }.font(.system(size: 11))
    }
    private func formatted(_ value: JSONValue, key: String) -> String {
        if let number = value.number {
            if ["used", "total", "available", "swap_used", "swap_total", "cached", "trash_size", "purgeable", "memory_bytes"].contains(key) { return FileSize.string(Int64(max(0, number))) }
            if ["cpu_temp", "gpu_temp", "battery_temp"].contains(key) { return number <= 0 ? "—" : String(format: "%.1f °C", number) }
            if ["usage", "used_percent", "percent", "capacity"].contains(key) { return String(format: "%.1f%%", number) }
            if ["read_rate", "write_rate", "rx_rate_mbs", "tx_rate_mbs"].contains(key) { return String(format: "%.2f MB/s", number) }
            if key.hasSuffix("power") { return number == 0 ? "—" : String(format: "%.1f W", number) }
        }
        if case .bool(let value) = value { return zh ? (value ? "是" : "否") : (value ? "Yes" : "No") }
        return value.display
    }
    private func label(_ key: String) -> String {
        let names = ["usage":"使用率", "per_core":"各核心", "per_core_estimated":"核心數據為估算", "load1":"1 分鐘負載", "load5":"5 分鐘負載", "load15":"15 分鐘負載", "core_count":"核心數", "logical_cpu":"邏輯核心", "p_core_count":"效能核心", "e_core_count":"節能核心", "used":"已用", "total":"總容量", "available":"可用", "used_percent":"使用率", "swap_used":"已用交換空間", "swap_total":"交換空間總量", "cached":"檔案快取", "pressure":"壓力", "mount":"掛載位置", "device":"裝置", "fstype":"檔案系統", "external":"外置", "smart_status":"磁碟狀態", "purgeable":"可清除空間", "read_rate":"讀取", "write_rate":"寫入", "name":"名稱", "rx_rate_mbs":"接收", "tx_rate_mbs":"傳送", "ip":"IP 位址", "percent":"電量", "status":"狀態", "time_left":"剩餘時間", "health":"健康", "cycle_count":"循環次數", "capacity":"最大容量", "cpu_temp":"CPU 溫度", "gpu_temp":"GPU 溫度", "battery_temp":"電池溫度", "fan_speed":"風扇轉速", "fan_count":"風扇數量", "system_power":"系統功耗", "adapter_power":"充電器功率", "battery_power":"電池功率", "note":"說明", "memory_used":"圖像記憶體已用", "memory_total":"圖像記憶體總量", "hardware":"硬件", "sensors":"感應器", "bluetooth":"藍牙", "network":"網絡", "batteries":"電池", "top_processes":"程序", "thermal":"溫度與電力", "memory":"記憶體", "disks":"磁碟", "disk_io":"磁碟讀寫", "model":"型號", "cpu_model":"處理器型號", "total_ram":"記憶體容量", "disk_size":"磁碟容量", "os_version":"系統版本", "refresh_rate":"螢幕更新率", "uptime":"運行時間", "collected_at":"收集時間", "host":"電腦", "proxy":"代理伺服器", "process_alerts":"程序提示", "zombie_count":"殘留程序數", "zombie_parents":"殘留程序來源"]
        return zh ? names[key] ?? key.replacingOccurrences(of: "_", with: " ") : key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
