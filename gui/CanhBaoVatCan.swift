import AppKit
import SwiftUI

@main
struct CanhBaoVatCan: App {
    private let simulation = Simulation(
        executable: CommandLine.arguments.dropFirst().first
            ?? ["/opt/homebrew/bin/vvp", "/usr/local/bin/vvp"].first {
                FileManager.default.isExecutableFile(atPath: $0)
            } ?? "vvp",
        binary: CommandLine.arguments.dropFirst(2).first
            ?? Bundle.main.path(forResource: "gui", ofType: "vvp") ?? "build/gui.vvp"
    )

    var body: some Scene {
        WindowGroup("Mô phỏng cảnh báo vật cản") {
            Dashboard(simulation: simulation)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 720, height: 560)
        .windowResizability(.contentMinSize)
    }
}

private struct Dashboard: View {
    let simulation: Simulation
    @State private var distance = 80
    @State private var enteredDistance = "80"
    @State private var noEcho = false
    @State private var reading: Reading?
    @State private var error: String?
    @FocusState private var editingDistance: Bool

    private let levels = ["An toàn", "Cảnh báo", "Nguy hiểm", "Lỗi Echo"]
    private let colors: [Color] = [.green, .orange, .red, .purple]

    private var color: Color {
        reading.map { colors[$0.level] } ?? .secondary
    }

    private var status: String {
        reading.map { levels[$0.level] } ?? (error == nil ? "Đang mô phỏng…" : "Lỗi mô phỏng")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Cảnh báo vật cản").font(.largeTitle.bold())
                Text("HC-SR04  ·  Mô phỏng Verilog 1 MHz").foregroundStyle(.secondary)
            }
            controls
            DistanceDiagram(distance: distance, color: color)
                .frame(height: 108)
                .padding(14)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            Divider()
            results
        }
        .padding(26)
        .frame(minWidth: 620, minHeight: 510, alignment: .topLeading)
        .onChange(of: distance) { enteredDistance = String(distance) }
        .onChange(of: editingDistance) {
            if !editingDistance { applyDistance() }
        }
        .task(id: distance * 2 + (noEcho ? 1 : 0)) {
            let sampleDistance = distance
            let sampleNoEcho = noEcho
            reading = nil
            error = nil
            do {
                try await Task.sleep(nanoseconds: 60_000_000)
                let result = try await Task.detached(priority: .userInitiated) {
                    try simulation.measure(distance: sampleDistance, noEcho: sampleNoEcho)
                }.value
                try Task.checkCancellation()
                reading = result
                error = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                reading = nil
                self.error = error.localizedDescription
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Khoảng cách vật cản").font(.headline)
                Spacer()
                TextField("Khoảng cách (cm)", text: $enteredDistance)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($editingDistance)
                    .onSubmit { applyDistance() }
                    .frame(width: 64)
                Text("cm").foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(distance) },
                                  set: { distance = Int($0.rounded()) }),
                   in: 2...400, step: 1) {
                Text("Khoảng cách vật cản")
            }
            .labelsHidden()
            HStack {
                Text("2 cm")
                Spacer()
                Text("400 cm")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Toggle("Giả lập mất Echo", isOn: $noEcho).toggleStyle(.checkbox)
        }
    }

    private func applyDistance() {
        if let entered = Int(enteredDistance.trimmingCharacters(in: .whitespaces)) {
            distance = min(400, max(2, entered))
        }
        enteredDistance = String(distance)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(status, systemImage: "waveform.path")
                .font(.title3.bold())
                .foregroundStyle(color)
            if let error {
                Text(error).foregroundStyle(.secondary)
            } else if let reading {
                Text(reading.valid
                     ? "Độ rộng xung Echo · \((distance * 58).formatted()) µs"
                     : "Không nhận được xung Echo hợp lệ")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                indicator("LED xanh", index: 0, tint: .green)
                indicator("LED vàng", index: 1, tint: .orange)
                indicator("LED đỏ", index: 2, tint: .red)
                indicator("Còi", index: 3, tint: .red)
            }
        }
    }

    private func indicator(_ name: String, index: Int, tint: Color) -> some View {
        let active = reading?.outputs[index] == true
        return HStack(spacing: 8) {
            Circle().fill(active ? tint : Color.secondary.opacity(0.28))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(reading == nil ? "—" : active ? "Bật" : "Tắt")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? tint.opacity(0.14) : Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DistanceDiagram: View {
    let distance: Int
    let color: Color

    var body: some View {
        GeometryReader { area in
            let start = 97.0
            let finish = max(start, area.size.width - 38)
            let x = start + (finish - start) * CGFloat(distance - 2) / 398
            Path { path in
                path.move(to: CGPoint(x: 72, y: 54))
                path.addLine(to: CGPoint(x: finish, y: 54))
            }
            .stroke(.secondary.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            Path { path in
                path.move(to: CGPoint(x: 72, y: 54))
                path.addLine(to: CGPoint(x: x, y: 54))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            HStack(spacing: 5) {
                Circle().fill(.background)
                Circle().fill(.background)
            }
            .frame(width: 42, height: 16)
            .padding(8)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            .position(x: 36, y: 54)
            Text("HC-SR04").font(.caption).foregroundStyle(.secondary)
                .position(x: 36, y: 88)
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 16, height: 41)
                .position(x: x, y: 54)
            Text("\(distance) cm").font(.subheadline.monospacedDigit().weight(.semibold))
                .position(x: x, y: 16)
            Text("Vật cản").font(.caption).foregroundStyle(.secondary)
                .position(x: x, y: 88)
        }
        .accessibilityLabel("Cảm biến đến vật cản: \(distance) cm")
    }
}
