import AVFoundation
import Foundation
import Network
import Speech

/// The macOS-side half of "Hey Cranberry". Cariberry hosts a small local
/// socket (127.0.0.1, loopback only — nothing external ever connects) that
/// the separate `cranberry/` Python service talks to. Cariberry is the long-
/// running always-on process, so it listens; the Python service, which you
/// start and stop yourself, connects to it.
///
/// Two things only travel over this socket:
///  - `say`: Cranberry's spoken/typed reply, shown as the pet's own speech
///    bubble via `Pet.say`, so voice replies look identical to her regular
///    dialogue.
///  - `transcribe`: a request to turn the next few seconds of microphone
///    audio into text. Cariberry already carries the on-device Speech
///    Recognition entitlement/usage strings (see Info.plist), so it does the
///    actual transcription and hands the text back — the Python service
///    never needs its own copy of that permission.
///
/// If the Python service isn't running, this sits idle: no pet behavior
/// depends on it, exactly like the rest of Cariberry's optional integrations.
@MainActor
final class CranberryBridge {
    private weak var pet: Pet?
    private let port: NWEndpoint.Port = 8765
    private var listener: NWListener?
    private var connection: NWConnection?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(pet: Pet) {
        self.pet = pet
    }

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .loopback
        guard let listener = try? NWListener(using: params, on: port) else {
            print("Cranberry bridge: couldn't open 127.0.0.1:\(port) — is another instance already running?")
            return
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func accept(_ connection: NWConnection) {
        self.connection?.cancel()
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { @MainActor in
                    if self?.connection === connection { self?.connection = nil }
                }
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive(on: connection, buffered: Data())
    }

    private func receive(on connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                var buffer = buffered
                if let data, !data.isEmpty {
                    buffer.append(data)
                }
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)
                    if !line.isEmpty { self.handle(line: Data(line), connection: connection) }
                }
                if isComplete || error != nil {
                    connection.cancel()
                    return
                }
                self.receive(on: connection, buffered: buffer)
            }
        }
    }

    private func handle(line: Data, connection: NWConnection) {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = message["type"] as? String else { return }

        switch type {
        case "say":
            guard let text = message["text"] as? String, !text.isEmpty else { return }
            let seconds = message["seconds"] as? Double ?? 3.5
            let mood = (message["mood"] as? String).flatMap(Emotion.init(rawValue:))
            pet?.say(text, mood, seconds)

        case "transcribe":
            let id = message["id"] as? String ?? UUID().uuidString
            let maxSeconds = message["max_seconds"] as? Double ?? 6.0
            transcribe(maxSeconds: maxSeconds) { [weak self] text in
                self?.send(["type": "transcribed", "id": id, "text": text], on: connection)
            }

        default:
            break
        }
    }

    private func send(_ payload: [String: Any], on connection: NWConnection) {
        guard var data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        data.append(0x0A)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - On-device speech-to-text

    /// Records from the default input device and transcribes on-device with
    /// `SFSpeechRecognizer`, stopping after `maxSeconds` or once the
    /// recognizer reports a final result. Calls back on the main actor with
    /// the best transcription, or `""` if permission was denied or nothing
    /// was heard.
    private func transcribe(maxSeconds: Double, completion: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard status == .authorized,
                      let self,
                      let recognizer = self.speechRecognizer,
                      recognizer.isAvailable else {
                    completion("")
                    return
                }
                self.record(with: recognizer, maxSeconds: maxSeconds, completion: completion)
            }
        }
    }

    private func record(with recognizer: SFSpeechRecognizer, maxSeconds: Double, completion: @escaping (String) -> Void) {
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            completion("")
            return
        }
        self.audioEngine = engine

        var lastText = ""
        var finished = false
        let finish: (String) -> Void = { [weak self] text in
            guard !finished else { return }
            finished = true
            inputNode.removeTap(onBus: 0)
            engine.stop()
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
            self?.audioEngine = nil
            completion(text)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result { lastText = result.bestTranscription.formattedString }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in finish(lastText) }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + maxSeconds) {
            request.endAudio()
            // Give the recognizer a moment to flush its final result before
            // we force a cutoff.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { finish(lastText) }
        }
    }
}
