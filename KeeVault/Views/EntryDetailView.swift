import SwiftUI

struct EntryDetailView: View {
    let entry: KPEntry

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: entry.systemIconName)
                        .font(.title)
                        .foregroundStyle(.tint)
                    Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                        .font(.title2.bold())
                }
            }

            if !entry.username.isEmpty {
                FieldRow(label: "Username", value: entry.username, icon: "person.fill")
            }

            if !entry.password.isEmpty {
                PasswordFieldRow(password: entry.password)
            }

            if !entry.url.isEmpty {
                URLFieldRow(url: entry.url)
            }

            if entry.totpConfig != nil {
                TOTPSection(config: entry.totpConfig!)
            }

            if !entry.notes.isEmpty {
                Section("Notes") {
                    Text(entry.notes)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            if !entry.customFields.isEmpty {
                Section("Custom Fields") {
                    ForEach(entry.customFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        FieldRow(label: key, value: value, icon: "text.justify.left")
                    }
                }
            }

            if !entry.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.fill, in: .capsule)
                        }
                    }
                }
            }
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Field Rows

struct FieldRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        Section(label) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(value)
                    .textSelection(.enabled)
                Spacer()
                CopyButton(text: value)
            }
        }
    }
}

struct PasswordFieldRow: View {
    let password: String
    @State private var revealed = false

    var body: some View {
        Section("Password") {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                if revealed {
                    Text(password)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text(String(repeating: "\u{2022}", count: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                }
                CopyButton(text: password)
            }
        }
    }
}

struct URLFieldRow: View {
    let url: String

    var body: some View {
        Section("URL") {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(url)
                    .textSelection(.enabled)
                Spacer()
                if let link = URL(string: url) {
                    Link(destination: link) {
                        Image(systemName: "arrow.up.right.square")
                    }
                }
                CopyButton(text: url)
            }
        }
    }
}

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            ClipboardService.copy(text)
            copied = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? Color.green : Color.accentColor)
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - TOTP Section

struct TOTPSection: View {
    let config: TOTPConfig
    @State private var totpVM: TOTPViewModel

    init(config: TOTPConfig) {
        self.config = config
        self._totpVM = State(initialValue: TOTPViewModel(config: config))
    }

    var body: some View {
        Section("One-Time Password") {
            HStack {
                CountdownRing(progress: totpVM.progress, seconds: totpVM.secondsRemaining)
                    .frame(width: 40, height: 40)

                Text(totpVM.code)
                    .font(.title.monospaced().bold())
                    .contentTransition(.numericText())

                Spacer()

                CopyButton(text: totpVM.code)
            }
        }
        .onAppear { totpVM.start() }
        .onDisappear { totpVM.stop() }
    }
}

struct CountdownRing: View {
    let progress: Double
    let seconds: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 3)
                .foregroundStyle(.quaternary)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(progress > 0.3 ? .green : .orange)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Text("\(seconds)")
                .font(.caption2.monospacedDigit())
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (offsets, CGSize(width: maxX, height: currentY + rowHeight))
    }
}
