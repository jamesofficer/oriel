//
//  ShortcutRecorder.swift
//  Oriel
//
//  Records one shortcut from the keyboard. The leader key is paused
//  during a recording, so the user can record the same key again.
//

import AppKit
import Combine

final class ShortcutRecorder: ObservableObject {
    @Published private(set) var errorMessage: String?
    @Published private var recording: Recording?

    var isRecording: Bool { recording != nil }

    private struct Recording {
        let coordinator: LeaderKeyCoordinator
        let keyMonitor: Any?
    }

    func start(pausing coordinator: LeaderKeyCoordinator, onRecord: @escaping (LeaderKey) -> Void) {
        guard recording == nil else { return }

        errorMessage = nil

        if case let .failure(error) = coordinator.pause() {
            fail(with: error)
            return
        }

        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            handle(event, onRecord: onRecord)
            return nil
        }
        recording = Recording(coordinator: coordinator, keyMonitor: keyMonitor)
    }

    /// Does nothing when no recording is in progress.
    func stop() {
        guard let recording else { return }

        if let keyMonitor = recording.keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }

        self.recording = nil

        do {
            try recording.coordinator.resume()
        } catch {
            fail(with: error)
        }
    }

    /// The leader key is still paused when onRecord runs. If the new
    /// key cannot register, stop() brings the previous key back.
    private func handle(_ event: NSEvent, onRecord: (LeaderKey) -> Void) {
        switch ShortcutCapture.from(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
        case .cancelled:
            stop()
        case .invalid:
            NSSound.beep()
        case let .shortcut(leaderKey):
            onRecord(leaderKey)
            stop()
        }
    }

    private func fail(with error: Error) {
        errorMessage = error.localizedDescription
        NSSound.beep()
    }
}
