import SwiftUI

/// Shared presentation for the direct and Store editions; no collector dependency.
struct MemoryUsageSummary: View {
    let used: UInt64?
    let total: UInt64?

    private var fraction: Double? {
        guard let used, let total, total > 0, used <= total else { return nil }
        return Double(used) / Double(total)
    }
    private func bytes(_ value: UInt64?) -> String {
        value.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) }
            ?? "Unavailable"
    }
    private var capacity: String {
        guard let total, total > 0 else { return "Installed memory unavailable" }
        return "of \(bytes(total)) installed"
    }
    private var amount: some View {
        Text(bytes(used))
            .font(.system(size: 42, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel("Memory used")
            .accessibilityValue(bytes(used))
            .accessibilityIdentifier("memory-used-value")
    }
    private var installed: some View {
        Text(capacity).font(.title3).foregroundStyle(.secondary)
            .accessibilityIdentifier("memory-installed-total")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory used", systemImage: "memorychip").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) { amount; installed }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) { amount; installed }
            }
            if let fraction {
                Text("\((fraction * 100).formatted(.number.precision(.fractionLength(1))))% of installed memory used")
                    .font(.subheadline.weight(.medium)).monospacedDigit()
                    .accessibilityIdentifier("memory-used-percent")
                ProgressView(value: fraction, total: 1).tint(.purple)
                    .accessibilityHidden(true) // The exact value is already exposed as text.
            } else {
                Text("Usage percentage unavailable").font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("memory-usage-unavailable")
            }
            Text("Active + wired + compressed RAM. Swap is separate.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.07), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("memory-usage-summary")
    }
}
