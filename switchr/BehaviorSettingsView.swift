//
//  BehaviorSettingsView.swift
//  switchr
//

import AppKit
import ServiceManagement
import SwiftUI

struct BehaviorSettingsView: View {
    @AppStorage(AppPreferences.Key.bringToCurrentScreen) private var bringToCurrentScreen = AppPreferences.defaultBringToCurrentScreen
    @AppStorage(AppPreferences.Key.maximizeOnFocus) private var maximizeOnFocus = AppPreferences.defaultMaximizeOnFocus
    @AppStorage(AppPreferences.Key.animatePanel) private var animatePanel = AppPreferences.defaultAnimatePanel
    @AppStorage(AppPreferences.Key.showClosedApps) private var showClosedApps = AppPreferences.defaultShowClosedApps
    @AppStorage(AppPreferences.Key.revealDelayMilliseconds) private var revealDelayMilliseconds = AppPreferences.defaultRevealDelayMilliseconds
    @AppStorage(AppPreferences.Key.panelOpacity) private var panelOpacity = AppPreferences.defaultPanelOpacity
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Section("Behavior") {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                Text("Automatically opens Switchr when you log in.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Bring window to current screen", isOn: $bringToCurrentScreen)
                Text("When enabled, switching moves the window to the screen the switcher is on, keeping its relative position. When off, the window is focused wherever it already is.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Maximize window when focused", isOn: $maximizeOnFocus)
                Text("When enabled, the focused window is resized to fill its screen edge to edge. This is a normal resize, not macOS full screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show closed apps with bindings", isOn: $showClosedApps)
                Text("Apps from App Bindings that aren't open are listed in the Pinned — Closed section. Pressing their key launches the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Switcher reveal delay")
                    Spacer()
                    TextField("", value: $revealDelayMilliseconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .fixedSize(horizontal: true, vertical: false)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Switcher reveal delay in milliseconds")
                        .onChange(of: revealDelayMilliseconds) { _, value in
                            revealDelayMilliseconds = min(
                                max(value, AppPreferences.revealDelayRange.lowerBound),
                                AppPreferences.revealDelayRange.upperBound
                            )
                        }
                    Text("ms")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                Text("Sets how long Switchr waits before it shows the panel. The value must be from 0 to 1000 milliseconds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Panel opacity")
                    Spacer()
                    Slider(value: $panelOpacity, in: AppPreferences.panelOpacityRange, step: 0.05)
                        .frame(width: 140)
                        .accessibilityLabel("Panel opacity")
                        .onChange(of: panelOpacity) { _, value in
                            panelOpacity = min(
                                max(value, AppPreferences.panelOpacityRange.lowerBound),
                                AppPreferences.panelOpacityRange.upperBound
                            )
                        }
                    Text(panelOpacity, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Sets how much of the desktop shows through the switcher panel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Animate window appearance", isOn: $animatePanel)
                Text("Fades the switcher in when it appears. When off, it appears instantly.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            NSSound.beep()
        }
    }
}
