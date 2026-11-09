// Hear it, read aloud with Apple's own speech engine.
// The web speech inside the app can't use the Premium or Enhanced voices people download in
// Settings > Accessibility > Spoken Content > Voices, so the iPhone app speaks through this instead.
// Picks the best installed voice for the language: Premium, then Enhanced, then the normal one,
// and never the novelty voices.
import Foundation
import AVFoundation
import Capacitor

@objc(TakeoffSpeechPlugin)
public class TakeoffSpeechPlugin: CAPPlugin, CAPBridgedPlugin, AVSpeechSynthesizerDelegate {
    public let identifier = "TakeoffSpeechPlugin"
    public let jsName = "TakeoffSpeech"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "speak", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "voice", returnType: CAPPluginReturnPromise)
    ]

    private let synth = AVSpeechSynthesizer()
    private var pending: CAPPluginCall?

    override public func load() {
        synth.delegate = self
    }

    private func score(_ v: AVSpeechSynthesisVoice, _ lang: String) -> Int {
        let l = lang.lowercased().replacingOccurrences(of: "_", with: "-")
        let base = String(l.prefix(2))
        let vl = v.language.lowercased()
        var n = 0
        if vl == l { n += 100 }
        else if vl.hasPrefix(base) { n += 50 + ((vl.hasSuffix("-us") || vl.hasSuffix("-mx")) ? 5 : 0) }
        else { return -1 }
        if #available(iOS 16.0, *), v.quality == .premium { n += 40 }
        else if v.quality == .enhanced { n += 30 }
        if #available(iOS 17.0, *), v.voiceTraits.contains(.isNoveltyVoice) { n -= 80 }
        let id = v.identifier.lowercased()
        if id.contains("eloquence") || id.contains("speech.synthesis.voice") { n -= 60 }
        return n
    }

    private func bestVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
        var best: AVSpeechSynthesisVoice?
        var bestScore = -1
        for v in AVSpeechSynthesisVoice.speechVoices() {
            let s = score(v, lang)
            if s > bestScore { bestScore = s; best = v }
        }
        return best ?? AVSpeechSynthesisVoice(language: lang)
    }

    private func qualityName(_ v: AVSpeechSynthesisVoice) -> String {
        if #available(iOS 16.0, *), v.quality == .premium { return "premium" }
        return v.quality == .enhanced ? "enhanced" : "default"
    }

    @objc func voice(_ call: CAPPluginCall) {
        let lang = call.getString("lang") ?? "en-US"
        guard let v = bestVoice(lang) else { call.resolve(["available": false]); return }
        call.resolve(["available": true, "name": v.name, "quality": qualityName(v), "lang": v.language])
    }

    @objc func speak(_ call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let lang = call.getString("lang") ?? "en-US"
        let rate = Float(call.getDouble("rate") ?? 0.9)
        DispatchQueue.main.async {
            if self.synth.isSpeaking { self.synth.stopSpeaking(at: .immediate) }
            self.finish()
            guard !text.isEmpty else { call.resolve(); return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            let u = AVSpeechUtterance(string: text)
            u.voice = self.bestVoice(lang)
            // the web rate 1.0 is normal speed; Apple's normal is AVSpeechUtteranceDefaultSpeechRate
            u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rate))
            u.pitchMultiplier = 1.0
            u.postUtteranceDelay = 0
            self.pending = call
            self.synth.speak(u)
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.synth.stopSpeaking(at: .immediate)
            self.finish()
            call.resolve()
        }
    }

    private func finish() {
        if let c = pending { pending = nil; c.resolve() }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.finish() }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.finish() }
    }
}
