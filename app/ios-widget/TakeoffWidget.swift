// Cleared for Takeoff – "Question of the day" home-screen widget (iPhone).
// Shows the same daily question as the app: it uses the same 30 shared questions (Questions.swift,
// made from index.html at build time) and the same day-picking math as qodIdxFor() in index.html,
// so the widget never needs to talk to the app. Tapping it opens clearedfortakeoff://qod.
import WidgetKit
import SwiftUI

private let navy = Color(red: 20 / 255, green: 48 / 255, blue: 79 / 255)      // #14304F
private let gold = Color(red: 242 / 255, green: 185 / 255, blue: 12 / 255)     // #F2B90C

/// Same as qodIdxFor() in index.html: the phone's local date, counted in days since 1 Jan 1970.
func qodIndex(for date: Date) -> Int {
    let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let midnight = utc.date(from: DateComponents(year: local.year, month: local.month, day: local.day)) ?? date
    let days = Int((midnight.timeIntervalSince1970 / 86400).rounded())
    let n = qodEnglish.count
    let step = n % 7 != 0 ? 7 : 1
    return ((days * step) % n + n) % n
}

struct QodEntry: TimelineEntry {
    let date: Date
    let index: Int
}

struct QodProvider: TimelineProvider {
    func placeholder(in context: Context) -> QodEntry { QodEntry(date: Date(), index: 0) }

    func getSnapshot(in context: Context, completion: @escaping (QodEntry) -> Void) {
        completion(QodEntry(date: Date(), index: qodIndex(for: Date())))
    }

    // Today's question now, then a fresh one at each of the next two midnights.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QodEntry>) -> Void) {
        let now = Date()
        var entries = [QodEntry(date: now, index: qodIndex(for: now))]
        let cal = Calendar.current
        var day = cal.startOfDay(for: now)
        for _ in 0..<2 {
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
            entries.append(QodEntry(date: day, index: qodIndex(for: day)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct QodView: View {
    let entry: QodEntry
    @Environment(\.widgetFamily) private var family

    private var spanish: Bool { (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") }

    var body: some View {
        let list = spanish ? qodSpanish : qodEnglish
        let question = list[min(max(entry.index, 0), list.count - 1)]
        VStack(alignment: .leading, spacing: 6) {
            Text(spanish ? "PREGUNTA DEL DÍA" : "QUESTION OF THE DAY")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(gold)
            Text(question)
                .font(.system(size: family == .systemSmall ? 15 : 18, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: false)
            Spacer(minLength: 0)
            Text(spanish ? "Toca para practicar ✈️" : "Tap to practice ✈️")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "clearedfortakeoff://qod"))
        .containerBackground(navy, for: .widget)
    }
}

@main
struct TakeoffWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TakeoffQuestionOfTheDay", provider: QodProvider()) { entry in
            QodView(entry: entry)
        }
        .configurationDisplayName("Question of the day")
        .description("A new airline interview question every day. Tap to practice it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
