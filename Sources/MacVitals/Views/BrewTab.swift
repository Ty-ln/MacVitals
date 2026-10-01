import SwiftUI

struct BrewTab: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusLine
                Spacer()
                Button {
                    state.checkBrew()
                } label: {
                    Label("Check now", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            if let error = state.brewError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let brew = state.brew {
                if brew.count == 0 {
                    Label("Everything's up to date", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .padding(.vertical, 6)
                } else if brew.count > 14 {
                    ScrollView { packageList(brew) }.frame(height: 340)
                } else {
                    packageList(brew)
                }
            }

            Text("Read only. Run `brew upgrade` in your terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.callout)
    }

    @ViewBuilder private var statusLine: some View {
        if state.brewChecking {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        } else if let last = state.brewLastChecked {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(checkedText(last: last, now: context.date))
                    .foregroundStyle(.secondary)
                    .help(nextCheckText(now: context.date))
            }
        } else {
            Text("Not checked yet").foregroundStyle(.secondary)
        }
    }

    private func checkedText(last: Date, now: Date) -> String {
        "Checked " + (now.timeIntervalSince(last) < 60 ? "just now" : Format.relative(last, to: now))
    }

    private func nextCheckText(now: Date) -> String {
        guard let next = state.brewNextCheck, next > now else { return "" }
        return "Next check " + Format.relative(next, to: now)
    }

    private func packageList(_ brew: BrewResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !brew.formulae.isEmpty { PackageSection(title: "Formulae · \(brew.formulae.count)", packages: brew.formulae) }
            if !brew.casks.isEmpty { PackageSection(title: "Casks · \(brew.casks.count)", packages: brew.casks) }
        }
    }
}

private struct PackageSection: View {
    let title: String
    let packages: [OutdatedPackage]

    var body: some View {
        SectionHeader(title: title)
        ForEach(packages) { package in
            HStack {
                Text(package.name).lineLimit(1)
                Spacer()
                Text(package.installed).foregroundStyle(.secondary)
                Text("→").foregroundStyle(.secondary)
                Text(package.latest)
            }
            .font(.system(size: 12, design: .monospaced))
        }
    }
}
