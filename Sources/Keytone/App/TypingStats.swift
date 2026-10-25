import Foundation

/// Pulsaciones de hoy, totales y velocidad de escritura en directo.
final class TypingStats: ObservableObject {
    @Published private(set) var today: Int
    @Published private(set) var total: Int
    @Published private(set) var wordsPerMinute = 0

    private let defaults = UserDefaults.standard
    private var day: String
    private var recent: [TimeInterval] = []
    private var unsaved = 0
    private var timer: Timer?

    /// Ventana para calcular las palabras por minuto (una palabra = 5 pulsaciones).
    private let window: TimeInterval = 15

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        day = defaults.string(forKey: "stats.day") ?? Self.dayFormatter.string(from: Date())
        today = defaults.integer(forKey: "stats.today")
        total = defaults.integer(forKey: "stats.total")
        rollOverIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateSpeed()
        }
    }

    func record() {
        rollOverIfNeeded()
        today += 1
        total += 1
        recent.append(ProcessInfo.processInfo.systemUptime)
        updateSpeed()
        unsaved += 1
        if unsaved >= 25 { save() }
    }

    func save() {
        defaults.set(day, forKey: "stats.day")
        defaults.set(today, forKey: "stats.today")
        defaults.set(total, forKey: "stats.total")
        unsaved = 0
    }

    private func updateSpeed() {
        let now = ProcessInfo.processInfo.systemUptime
        recent.removeAll { now - $0 > window }
        let wpm = Int((Double(recent.count) / 5) * (60 / window))
        if wpm != wordsPerMinute { wordsPerMinute = wpm }
    }

    private func rollOverIfNeeded() {
        let current = Self.dayFormatter.string(from: Date())
        if current != day {
            day = current
            today = 0
            save()
        }
    }
}
