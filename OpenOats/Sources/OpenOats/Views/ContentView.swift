import SwiftUI

struct ContentView: View {
    private enum ControlBarAction {
        case toggle
        case confirmDownload
    }

    @Bindable var settings: AppSettings
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @State private var overlayManager = OverlayManager()
    @State private var miniBarManager = MiniBarManager()
    @State private var liveSessionController: LiveSessionController?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showConsentSheet = false
    @State private var deferredConsentAction: ControlBarAction?

    // MARK: - Interview Session State

    @State private var sessionTitle = ""
    @State private var interviewSetup = InterviewSetup()
    @State private var sessionNotes: [BANote] = []
    @State private var interviewTags: [InterviewTag] = []
    @State private var screenshots: [ScreenshotCapture] = []

    var body: some View {
        bodyWithModifiers
    }

    // MARK: - Root Content Router

    private var rootContent: some View {
        let controllerState = liveSessionController?.state ?? LiveSessionState()

        return Group {
            if controllerState.isRunning {
                InterviewWorkspaceView(
                    controllerState: controllerState,
                    sessionTitle: sessionTitle,
                    interviewSetup: interviewSetup,
                    notes: $sessionNotes,
                    interviewTags: $interviewTags,
                    screenshots: $screenshots,
                    onStop: { stopSession() },
                    onMuteToggle: { liveSessionController?.toggleMicMute() },
                    onCaptureScreenshot: {
                        if settings.hideFromScreenShare && !settings.temporaryScreenshotVisibilityEnabled {
                            settings.setTemporaryScreenshotVisibilityEnabled(true)
                        }
                        liveSessionController?.captureScreenshot()
                    },
                    onToggleScreenshotVisibility: {
                        settings.setTemporaryScreenshotVisibilityEnabled(!settings.temporaryScreenshotVisibilityEnabled)
                    }
                )
            } else {
                SessionSetupView(
                    sessionTitle: $sessionTitle,
                    interviewSetup: $interviewSetup,
                    controllerState: controllerState,
                    onStartInterview: {
                        handleControlBarAction(.toggle)
                    },
                    onConfirmDownload: {
                        handleControlBarAction(.confirmDownload)
                    },
                    onOpenPastInterviews: {
                        openWindow(id: "notes")
                    }
                )
            }
        }
    }

    private var bodyWithModifiers: some View {
        contentWithEventHandlers
    }

    private var sizedRootContent: some View {
        rootContent
            .frame(minWidth: 900, minHeight: 500)
            .background(.ultraThinMaterial)
    }

    private var contentWithOverlay: some View {
        sizedRootContent.overlay {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            }
            if showConsentSheet {
                RecordingConsentView(
                    isPresented: $showConsentSheet,
                    settings: settings
                )
                .transition(.opacity)
            }
        }
    }

    private var contentWithLifecycle: some View {
        contentWithOverlay
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing {
                hasCompletedOnboarding = true
            }
        }
        .onChange(of: showConsentSheet) { _, isShowing in
            guard !isShowing else { return }

            let deferredAction = deferredConsentAction
            deferredConsentAction = nil

            guard settings.hasAcknowledgedRecordingConsent,
                  !(liveSessionController?.state.isRunning ?? false)
            else {
                return
            }

            if let deferredAction {
                handleControlBarAction(deferredAction)
            } else {
                liveSessionController?.startSession(
                    settings: settings,
                    interviewSetup: interviewSetup.isEmpty ? nil : interviewSetup,
                    title: sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sessionTitle
                )
            }
        }
        .task {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
            if coordinator.knowledgeBase == nil {
                container.ensureServicesInitialized(settings: settings, coordinator: coordinator)
            }
            coordinator.activeSettings = settings

            let controller = LiveSessionController(coordinator: coordinator, container: container)
            controller.onRunningStateChanged = { [weak miniBarManager, weak overlayManager] isRunning in
                if isRunning {
                    miniBarManager?.state.onTap = {
                        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == OpenOatsRootApp.mainWindowID }) {
                            window.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                    showMiniBar(controller: controller, miniBarManager: miniBarManager)
                    if settings.sidebarMode == .classicSuggestions {
                        coordinator.suggestionEngine?.startPreFetching()
                    }
                    if settings.suggestionPanelEnabled {
                        showSidebarContent()
                    }
                } else {
                    miniBarManager?.hide()
                    coordinator.suggestionEngine?.stopPreFetching()
                    overlayManager?.hideAfterDelay(seconds: 2)
                }
            }
            controller.openNotesWindow = {
                openWindow(id: "notes")
            }
            controller.onScreenshotCaptured = { [self] capture in
                screenshots.append(capture)
            }
            controller.onMiniBarContentUpdate = { [weak controller, weak miniBarManager] in
                showMiniBar(controller: controller, miniBarManager: miniBarManager)
            }
            coordinator.liveSessionController = controller
            liveSessionController = controller

            overlayManager.defaults = container.defaults
            miniBarManager.defaults = container.defaults
            await container.seedIfNeeded(coordinator: coordinator)
            controller.indexKBIfNeeded(settings: settings)
            controller.handlePendingExternalCommandIfPossible(settings: settings) {
                openWindow(id: "notes")
            }

            await controller.performInitialSetup()

            if settings.meetingAutoDetectEnabled {
                container.enableDetection(settings: settings, coordinator: coordinator)
                await container.detectionController?.evaluateImmediate()
            }

            await controller.runPollingLoop(settings: settings)
        }
        .onChange(of: settings.meetingAutoDetectEnabled) {
            if settings.meetingAutoDetectEnabled {
                container.enableDetection(settings: settings, coordinator: coordinator)
                Task {
                    await container.detectionController?.evaluateImmediate()
                }
            } else {
                container.disableDetection(coordinator: coordinator)
            }
        }
        .onChange(of: settings.sidebarMode) {
            if settings.sidebarMode == .classicSuggestions {
                coordinator.suggestionEngine?.startPreFetching()
            } else {
                coordinator.suggestionEngine?.stopPreFetching()
            }
            guard liveSessionController?.state.isRunning == true, settings.suggestionPanelEnabled else { return }
            showSidebarContent()
        }
    }

    private var contentWithEventHandlers: some View {
        contentWithLifecycle
        .onKeyPress(.escape) {
            overlayManager.hide()
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSuggestionPanel)) { _ in
            toggleOverlay()
        }
    }

    // MARK: - Actions

    private func startSession() {
        guard settings.hasAcknowledgedRecordingConsent else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showConsentSheet = true
            }
            return
        }
        liveSessionController?.startSession(
            settings: settings,
            interviewSetup: interviewSetup.isEmpty ? nil : interviewSetup,
            title: sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sessionTitle
        )
    }

    private func stopSession() {
        liveSessionController?.saveInterviewArtifacts(
            notes: sessionNotes,
            tags: interviewTags,
            screenshots: screenshots
        )
        liveSessionController?.stopSession(settings: settings)
        sessionNotes = []
        interviewTags = []
        screenshots = []
    }

    private func showMiniBar(controller: LiveSessionController?, miniBarManager: MiniBarManager?) {
        guard let controller, let miniBarManager else { return }
        miniBarManager.update(
            audioLevel: controller.state.audioLevel,
            suggestions: controller.state.suggestions,
            isGenerating: controller.state.isGeneratingSuggestions,
            micCaptureStatus: controller.state.micCaptureStatus,
            systemAudioCaptureStatus: controller.state.systemAudioCaptureStatus
        )
        miniBarManager.show()
    }

    private func toggleOverlay() {
        switch settings.sidebarMode {
        case .classicSuggestions:
            overlayManager.toggle(content: SuggestionPanelContent(engine: coordinator.suggestionEngine))
        case .sidecast:
            overlayManager.toggleSidecast(content: sidecastContent())
        }
    }

    private func showSidebarContent() {
        switch settings.sidebarMode {
        case .classicSuggestions:
            overlayManager.showSidePanel(content: SuggestionPanelContent(engine: coordinator.suggestionEngine))
        case .sidecast:
            overlayManager.showSidecastSidebar(content: sidecastContent())
        }
    }

    private func sidecastContent() -> SidecastPanelContent {
        SidecastPanelContent(settings: settings, engine: coordinator.sidecastEngine)
    }

    @MainActor
    private func handleControlBarAction(_ action: ControlBarAction) {
        guard settings.hasAcknowledgedRecordingConsent else {
            deferredConsentAction = action
            withAnimation(.easeInOut(duration: 0.25)) {
                showConsentSheet = true
            }
            return
        }

        switch action {
        case .toggle:
            if liveSessionController?.state.isRunning ?? false {
                stopSession()
            } else {
                startSession()
            }
        case .confirmDownload:
            liveSessionController?.confirmDownloadAndStart(
                settings: settings,
                interviewSetup: interviewSetup.isEmpty ? nil : interviewSetup,
                title: sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sessionTitle
            )
        }
    }
}

// MARK: - InterviewSetup Convenience

extension InterviewSetup {
    var isEmpty: Bool {
        processArea.trimmingCharacters(in: .whitespaces).isEmpty
        && intervieweeRole.trimmingCharacters(in: .whitespaces).isEmpty
        && objective.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
