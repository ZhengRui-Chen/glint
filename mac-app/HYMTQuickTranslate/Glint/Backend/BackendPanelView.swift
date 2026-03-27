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
            Text(L10n.backendSettingsTitle)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(L10n.backendSettingsSubtitle)
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundStyle(visualStyle.secondaryTextColor)
        }
    }

    @ViewBuilder
    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.backendModeLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(visualStyle.secondaryTextColor)

            Picker("", selection: modeBinding) {
                Text(L10n.backendModeManagedLocal)
                    .tag(BackendMode.managedLocal)
                Text(L10n.backendModeExternalAPI)
                    .tag(BackendMode.externalAPI)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var configurationFields: some View {
        VStack(spacing: 12) {
            field(title: L10n.backendBaseURL) {
                TextField(
                    "",
                    text: baseURLBinding,
                    prompt: Text(L10n.backendBaseURLPlaceholder)
                )
                .textFieldStyle(.roundedBorder)
            }

            field(title: L10n.backendModel) {
                TextField(
                    "",
                    text: modelBinding,
                    prompt: Text(L10n.backendModelPlaceholder)
                )
                .textFieldStyle(.roundedBorder)
            }

            field(title: L10n.backendAPIKey) {
                SecureField(
                    "",
                    text: apiKeyBinding,
                    prompt: Text(L10n.backendAPIKeyPlaceholder)
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
            Button(L10n.checkBackend, action: onCheckBackend)
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
