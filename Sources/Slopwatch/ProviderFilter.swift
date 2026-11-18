import SwiftUI

struct ProviderFilter: View {
    let model: DashboardModel
    var body: some View {
        HStack(spacing: 4) {
            choice(nil, title: "All activity")
            ForEach(Provider.allCases) { provider in choice(provider, title: provider.rawValue) }
            Spacer()
        }
    }
    private func choice(_ provider: Provider?, title: String) -> some View {
        let selected = model.provider == provider
        return Button { model.provider = provider } label: {
            HStack(spacing: 5) {
                if let provider { ProviderIcon(provider: provider, size: 16) }
                Text(title).font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(selected ? Color.primary.opacity(0.09) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
