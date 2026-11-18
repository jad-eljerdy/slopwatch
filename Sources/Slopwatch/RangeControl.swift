import SwiftUI

struct RangeControl: View {
    let model: DashboardModel
    var body: some View {
        Picker("Time range", selection: Binding(get: { model.interval }, set: model.select)) {
            ForEach(Interval.allCases) { item in Text(item.label).tag(item) }
        }
        .labelsHidden().pickerStyle(.segmented).controlSize(.small).frame(width: 134)
        .accessibilityLabel("Time range")
    }
}
