import SwiftUI

struct BackendPanelView: View {
    @ObservedObject var viewModel: BackendPanelViewModel

    let onCheckBackend: () -> Void
    let onStartService: () -> Void
    let onStopService: () -> Void
    let onRestartService: () -> Void
    let onResetToDefaults: () -> Void
    let onDone: () -> Void

    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 14) {
                modePicker
                configurationFields
            }

            statusBlock

            actionArea

            HStack(spacing: 12) {
                Button(L10n.resetToDefaults, action: onResetToDefaults)
                    .buttonStyle(.bordered)
                Spacer()
                Button(L10n.done, action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(
            OverlayBackgroundView(
                visualStyle: visualStyle,
                averageLuminance: nil
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: OverlayVisualStyle.cornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: viewModel.draftSettings.mode)
        .animation(.easeOut(duration: 0.18), value: viewModel.statusHeadline)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Backend Settings", comment: "Title for the backend settings panel"))
                .font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(
                String(
                    localized: "Choose how Glint connects to the translation backend.",
                    comment: "Subtitle for the backend settings panel"
                )
            )
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundStyle(visualStyle.secondaryTextColor)
        }
    }

    @ViewBuilder
    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Mode", comment: "Backend mode field label"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)

            Picker("", selection: modeBinding) {
                Text(String(localized: "Managed Local", comment: "Managed local backend mode label"))
                    .tag(BackendMode.managedLocal)
                Text(String(localized: "External API", comment: "External API backend mode label"))
                    .tag(BackendMode.externalAPI)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var configurationFields: some View {
        VStack(spacing: 12) {
            field(
                title: String(localized: "Base URL", comment: "Backend base URL field label")
            ) {
                TextField(
                    "",
                    text: baseURLBinding,
                    prompt: Text("http://127.0.0.1:8001")
                )
                .textFieldStyle(.roundedBorder)
            }

            field(
                title: String(localized: "Model", comment: "Backend model field label")
            ) {
                TextField(
                    "",
                    text: modelBinding,
                    prompt: Text("deepseek-ai/DeepSeek-V3")
                )
                .textFieldStyle(.roundedBorder)
            }

            field(
                title: String(localized: "API Key", comment: "Backend API key field label")
            ) {
                SecureField(
                    "",
                    text: apiKeyBinding,
                    prompt: Text("sk-...")
                )
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.statusHeadline)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            Text(viewModel.statusDetail)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(visualStyle.surfaceFillOpacity + 0.06))
        )
    }

    @ViewBuilder
    private var actionArea: some View {
        HStack(spacing: 8) {
            Button(
                String(localized: "Check Backend", comment: "Action that checks backend reachability"),
                action: onCheckBackend
            )
            .buttonStyle(.bordered)

            if viewModel.showsManagedControlActions {
                Button(L10n.startService, action: onStartService)
                    .buttonStyle(.bordered)
                Button(L10n.stopService, action: onStopService)
                    .buttonStyle(.bordered)
                Button(L10n.restartService, action: onRestartService)
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)
            content()
        }
    }

    private var modeBinding: Binding<BackendMode> {
        Binding(
            get: { viewModel.draftSettings.mode },
            set: { viewModel.updateMode($0) }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { viewModel.baseURLText },
            set: { viewModel.updateBaseURL($0) }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { viewModel.modelText },
            set: { viewModel.updateModel($0) }
        )
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { viewModel.apiKeyText },
            set: { viewModel.updateAPIKey($0) }
        )
    }
}
