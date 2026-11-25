import SwiftUI
import Combine

private enum Team: Equatable {
    case blue
    case red
}

private enum UnitKind {
    case tank
    case harvester

    var title: String {
        switch self {
        case .tank: return "坦克"
        case .harvester: return "采矿车"
        }
    }

    var cost: Int {
        switch self {
        case .tank: return 300
        case .harvester: return 200
        }
    }

    var maxHP: Double {
        switch self {
        case .tank: return 100
        case .harvester: return 140
        }
    }
}

private struct Unit: Identifiable {
    let id = UUID()
    var team: Team
    var kind: UnitKind
    var x: CGFloat
    var y: CGFloat
    var destinationX: CGFloat
    var destinationY: CGFloat
    var hp: Double
    var cooldown: Double = 0
}

struct GameView: View {
    @State private var units: [Unit] = [
        Unit(team: .blue, kind: .tank, x: 170, y: 255, destinationX: 170, destinationY: 255, hp: 100),
        Unit(team: .blue, kind: .tank, x: 170, y: 345, destinationX: 170, destinationY: 345, hp: 100),
        Unit(team: .blue, kind: .harvester, x: 115, y: 420, destinationX: 115, destinationY: 420, hp: 140),
        Unit(team: .red, kind: .tank, x: 820, y: 255, destinationX: 820, destinationY: 255, hp: 100),
        Unit(team: .red, kind: .tank, x: 820, y: 345, destinationX: 820, destinationY: 345, hp: 100)
    ]
    @State private var credits = 800
    @State private var selectedID: UUID?
    @State private var blueBaseHP = 500.0
    @State private var redBaseHP = 500.0
    @State private var tickCount = 0
    @State private var result: String?

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let mapWidth: CGFloat = 1000
    private let mapHeight: CGFloat = 600

    var body: some View {
        VStack(spacing: 10) {
            header
            battlefield
                .aspectRatio(1.42, contentMode: .fit)
                .overlay {
                    if let result {
                        resultOverlay(result)
                    }
                }
            controls
            Text("点选蓝色部队，再点击地图下达移动命令。部队会自动攻击附近敌军。")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.10, blue: 0.11).ignoresSafeArea())
        .onReceive(timer) { _ in tick() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("红色警戒：前线")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text("迷你即时战略")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text("◆ \(credits)")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.yellow)
                HStack(spacing: 8) {
                    Text("我方基地 \(Int(max(0, blueBaseHP)))")
                        .foregroundStyle(Color.cyan)
                    Text("敌方 \(Int(max(0, redBaseHP)))")
                        .foregroundStyle(Color.red.opacity(0.9))
                }
                .font(.system(size: 10, weight: .semibold))
            }
        }
        .padding(.horizontal, 4)
    }

    private var battlefield: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawBattlefield(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                issueCommand(at: value.location, size: proxy.size)
            })
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            buildButton(kind: .tank, symbol: "●")
            buildButton(kind: .harvester, symbol: "▰")
            Button(action: restart) {
                Label("重开", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ControlButtonStyle(tint: Color.gray))
        }
        .frame(height: 48)
    }

    private func buildButton(kind: UnitKind, symbol: String) -> some View {
        Button {
            guard result == nil, credits >= kind.cost else { return }
            credits -= kind.cost
            let startX: CGFloat = 150
            let startY: CGFloat = kind == .tank ? 300 : 425
            let unit = Unit(team: .blue, kind: kind, x: startX, y: startY,
                            destinationX: startX, destinationY: startY, hp: kind.maxHP)
            units.append(unit)
            selectedID = unit.id
        } label: {
            VStack(spacing: 2) {
                Text("\(symbol) 造\(kind.title)").font(.system(size: 12, weight: .bold))
                Text("\(kind.cost) 资金").font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ControlButtonStyle(tint: kind == .tank ? Color.blue : Color.teal))
        .disabled(credits < kind.cost || result != nil)
    }

    private func resultOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).font(.title2.weight(.heavy)).foregroundStyle(.white)
            Button("再来一局", action: restart)
                .buttonStyle(ControlButtonStyle(tint: .blue))
                .frame(width: 150)
        }
        .padding(22)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }

    private func drawBattlefield(in context: inout GraphicsContext, size: CGSize) {
        let sx = size.width / mapWidth
        let sy = size.height / mapHeight
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
        }

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.22, green: 0.31, blue: 0.22)))
        for x in stride(from: CGFloat(0), through: mapWidth, by: 50) {
            var line = Path(); line.move(to: point(x, 0)); line.addLine(to: point(x, mapHeight))
            context.stroke(line, with: .color(.white.opacity(0.035)), lineWidth: 1)
        }
        for y in stride(from: CGFloat(0), through: mapHeight, by: 50) {
            var line = Path(); line.move(to: point(0, y)); line.addLine(to: point(mapWidth, y))
            context.stroke(line, with: .color(.white.opacity(0.035)), lineWidth: 1)
        }

        // A central road and scattered cover make the map read like a small RTS battlefield.
        context.fill(Path(roundedRect: rect(0, 270, 1000, 60), cornerRadius: 4), with: .color(Color(red: 0.36, green: 0.34, blue: 0.27)))
        for (x, y, w, h) in [(320.0, 105.0, 62.0, 42.0), (470.0, 420.0, 72.0, 48.0), (650.0, 105.0, 58.0, 55.0), (350.0, 450.0, 42.0, 34.0)] {
            context.fill(Path(roundedRect: rect(x, y, w, h), cornerRadius: 7), with: .color(Color(red: 0.15, green: 0.20, blue: 0.16)))
        }
        // Ore patches.
        for (x, y) in [(260.0, 190.0), (285.0, 205.0), (735.0, 410.0), (765.0, 390.0), (745.0, 435.0)] {
            let oreRect = CGRect(x: point(x, y).x, y: point(x, y).y, width: 14 * sx, height: 12 * sy)
            context.fill(Path(ellipseIn: oreRect), with: .color(Color(red: 0.91, green: 0.69, blue: 0.18)))
        }

        drawBase(at: point(100, 300), team: .blue, hp: blueBaseHP, context: &context, scale: sx)
        drawBase(at: point(900, 300), team: .red, hp: redBaseHP, context: &context, scale: sx)

        for unit in units {
            let p = point(unit.x, unit.y)
            let color: Color = unit.team == .blue ? .cyan : Color(red: 0.95, green: 0.26, blue: 0.20)
            let radius = unit.kind == .tank ? 15 * sx : 17 * sx
            if selectedID == unit.id {
                context.stroke(Path(ellipseIn: CGRect(x: p.x - radius - 5, y: p.y - radius - 5, width: (radius + 5) * 2, height: (radius + 5) * 2)), with: .color(.yellow), lineWidth: 2)
            }
            let body = CGRect(x: p.x - radius, y: p.y - radius * 0.7, width: radius * 2, height: radius * 1.4)
            context.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(color))
            var barrel = Path(); barrel.move(to: CGPoint(x: p.x, y: p.y)); barrel.addLine(to: CGPoint(x: p.x + (unit.team == .blue ? 14 : -14) * sx, y: p.y))
            context.stroke(barrel, with: .color(.white.opacity(0.9)), lineWidth: max(2, 3 * sx))
            let hpWidth = 34 * sx
            context.fill(Path(CGRect(x: p.x - hpWidth / 2, y: p.y - radius - 8 * sy, width: hpWidth, height: 4 * sy)), with: .color(.black.opacity(0.65)))
            context.fill(Path(CGRect(x: p.x - hpWidth / 2, y: p.y - radius - 8 * sy, width: hpWidth * max(0, unit.hp / unit.kind.maxHP), height: 4 * sy)), with: .color(.green))
        }
    }

    private func drawBase(at center: CGPoint, team: Team, hp: Double, context: inout GraphicsContext, scale: CGFloat) {
        let color: Color = team == .blue ? Color.blue : Color.red
        let w = 76 * scale; let h = 70 * scale
        let baseRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        context.fill(Path(roundedRect: baseRect, cornerRadius: 9), with: .color(color.opacity(0.82)))
        context.stroke(Path(roundedRect: baseRect, cornerRadius: 9), with: .color(.white.opacity(0.75)), lineWidth: 2)
        let label = Text(team == .blue ? "基地" : "敌营").font(.system(size: max(9, 13 * scale), weight: .heavy)).foregroundColor(.white)
        context.draw(label, at: center)
        let barWidth = 82 * scale
        context.fill(Path(CGRect(x: center.x - barWidth / 2, y: center.y + h / 2 + 5, width: barWidth, height: 5)), with: .color(.black.opacity(0.7)))
        context.fill(Path(CGRect(x: center.x - barWidth / 2, y: center.y + h / 2 + 5, width: barWidth * max(0, hp / 500), height: 5)), with: .color(team == .blue ? .cyan : .red))
    }

    private func issueCommand(at location: CGPoint, size: CGSize) {
        guard result == nil else { return }
        let x = location.x / size.width * mapWidth
        let y = location.y / size.height * mapHeight
        if let friendly = units.first(where: { $0.team == .blue && hypot($0.x - x, $0.y - y) < 38 }) {
            selectedID = friendly.id
            return
        }
        guard let selectedID, let selectedIndex = units.firstIndex(where: { $0.id == selectedID }) else { return }
        let destinationX = min(mapWidth - 30, max(30, x))
        let destinationY = min(mapHeight - 30, max(30, y))
        units[selectedIndex].destinationX = destinationX
        units[selectedIndex].destinationY = destinationY
    }

    private func tick() {
        guard result == nil else { return }
        tickCount += 1
        if tickCount.isMultiple(of: 30) {
            credits += units.filter { $0.team == .blue && $0.kind == .harvester }.count * 25
        }

        var next = units
        let snapshot = units
        for index in next.indices {
            next[index].cooldown = max(0, next[index].cooldown - 0.1)
            let team = next[index].team
            if team == .red {
                next[index].destinationX = 120
                next[index].destinationY = 300
            }

            let opponentIndices = snapshot.indices.filter { snapshot[$0].team != team }
            if let target = opponentIndices.min(by: {
                distance(snapshot[index].x, snapshot[index].y, snapshot[$0].x, snapshot[$0].y) <
                distance(snapshot[index].x, snapshot[index].y, snapshot[$1].x, snapshot[$1].y)
            }), distance(snapshot[index].x, snapshot[index].y, snapshot[target].x, snapshot[target].y) < 54 {
                if next[index].cooldown <= 0 {
                    next[target].hp -= team == .blue ? 13 : 10
                    next[index].cooldown = 0.8
                }
                continue
            }

            let baseX: CGFloat = team == .blue ? 900 : 100
            let baseY: CGFloat = 300
            let baseDistance = distance(next[index].x, next[index].y, baseX, baseY)
            if baseDistance < 68 {
                if next[index].cooldown <= 0 {
                    if team == .blue { redBaseHP -= 12 } else { blueBaseHP -= 10 }
                    next[index].cooldown = 0.8
                }
                continue
            }

            let dx = next[index].destinationX - next[index].x
            let dy = next[index].destinationY - next[index].y
            let remaining = hypot(dx, dy)
            if remaining > 2 {
                let speed: CGFloat = next[index].kind == .tank ? 3.2 : 2.0
                next[index].x += dx / remaining * min(speed, remaining)
                next[index].y += dy / remaining * min(speed, remaining)
            }
        }

        let defeatedEnemies = next.filter { $0.team == .red && $0.hp <= 0 }.count
        if defeatedEnemies > 0 { credits += defeatedEnemies * 100 }
        units = next.filter { $0.hp > 0 }
        if redBaseHP <= 0 { redBaseHP = 0; result = "胜利！敌方基地已摧毁" }
        if blueBaseHP <= 0 { blueBaseHP = 0; result = "基地失守！" }
    }

    private func distance(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat {
        hypot(x1 - x2, y1 - y2)
    }

    private func restart() {
        units = [
            Unit(team: .blue, kind: .tank, x: 170, y: 255, destinationX: 170, destinationY: 255, hp: 100),
            Unit(team: .blue, kind: .tank, x: 170, y: 345, destinationX: 170, destinationY: 345, hp: 100),
            Unit(team: .blue, kind: .harvester, x: 115, y: 420, destinationX: 115, destinationY: 420, hp: 140),
            Unit(team: .red, kind: .tank, x: 820, y: 255, destinationX: 820, destinationY: 255, hp: 100),
            Unit(team: .red, kind: .tank, x: 820, y: 345, destinationX: 820, destinationY: 345, hp: 100)
        ]
        credits = 800
        selectedID = nil
        blueBaseHP = 500
        redBaseHP = 500
        tickCount = 0
        result = nil
    }
}

private struct ControlButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint.opacity(configuration.isPressed ? 0.55 : 0.82), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.16), lineWidth: 1))
    }
}

private extension UnitKind {
    static func == (lhs: UnitKind, rhs: UnitKind) -> Bool {
        switch (lhs, rhs) {
        case (.tank, .tank), (.harvester, .harvester): return true
        default: return false
        }
    }
}
