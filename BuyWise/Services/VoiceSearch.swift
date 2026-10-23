import AVFoundation
import Observation
import Speech

/// Turns speech into search text, on device when the phone supports it.
@Observable
final class VoiceSearch {
    private(set) var isListening = false
    private(set) var transcript = ""
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?

    func toggle() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard await Self.requestSpeechPermission(), await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Allow microphone and speech recognition access in Settings to search by voice."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Voice search isn't available right now. Check your connection and try again."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .search
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            Self.installTap(on: audioEngine.inputNode, request: request)
            audioEngine.prepare()
            try audioEngine.start()

            self.request = request
            transcript = ""
            isListening = true
            // `stop()` releases the task, so holding self here doesn't leak.
            recognitionTask = Self.recognize(with: recognizer, request: request) { text, isFinal in
                Task { @MainActor in self.update(text: text, isFinal: isFinal) }
            }
            restartSilenceTimer()
        } catch {
            stop()
            errorMessage = "Couldn't start the microphone. Try again."
        }
    }

    func stop() {
        silenceTimer?.cancel()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // Remove the tap even if the engine never started, or the next installTap would crash.
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        recognitionTask?.finish()
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func update(text: String?, isFinal: Bool) {
        guard isListening else { return }
        if let text {
            transcript = text.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            restartSilenceTimer()
        }
        if isFinal || text == nil { stop() }
    }

    // Stop once the user pauses, so they don't have to tap the mic again.
    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        let delay: Duration = transcript.isEmpty ? .seconds(6) : .seconds(1.5)
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    // iOS calls the audio and speech callbacks on background threads, so set them up outside
    // the main actor. Otherwise Swift crashes when they run off the main thread.

    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    /// Calls `onUpdate` with the latest text, or nil when recognition fails.
    nonisolated private static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                onUpdate(result.bestTranscription.formattedString, result.isFinal)
            } else if error != nil {
                onUpdate(nil, true)
            }
        }
    }

    nonisolated private static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }
}
