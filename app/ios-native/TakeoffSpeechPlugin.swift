// Hear it, read aloud with Apple's own speech engine.
// The web speech inside the app can't use the Premium or Enhanced voices people download in
// Settings > Accessibility > Spoken Content > Voices, so the iPhone app speaks through this instead.
// Picks the best installed voice for the language: Premium, then Enhanced, then the normal one,
// never the novelty voices. Safety net: if speech hasn't really started within 2 seconds
// (some downloaded voices stay silent), it retries once with the normal Apple voice, and if that
// is silent too it reports a failure so the app falls back to its web voice.
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
    private var started = false
    private var attempt = 0
    private var token = 0
    private var text = ""
    private var lang = "en-US"
    private var rate: Float = 0.9
    private var usedVoice: AVSpeechSynthesisVoice?
    private var gotStart = false
    private var gotWords = false
    private var notes: [String] = []

    private func note(_ v: AVSpeechSynthesisVoice?) {
        notes.append("\(v?.name ?? "no voice")(\(qualityName(v))) start:\(gotStart ? "yes" : "no") words:\(gotWords ? "yes" : "no")")
    }

    override public func load() {
        synth.delegate = self
        synth.usesApplicationAudioSession = false
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
        if #available(iOS 17.0, *), v.voiceTraits.contains(.isPersonalVoice) { n -= 80 }
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

    private func plainVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
        return AVSpeechSynthesisVoice(language: lang)
            ?? AVSpeechSynthesisVoice(language: String(lang.prefix(2)))
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func qualityName(_ v: AVSpeechSynthesisVoice?) -> String {
        guard let v = v else { return "none" }
        if #available(iOS 16.0, *), v.quality == .premium { return "premium" }
        return v.quality == .enhanced ? "enhanced" : "default"
    }

    @objc func voice(_ call: CAPPluginCall) {
        let lang = call.getString("lang") ?? "en-US"
        let v = bestVoice(lang)
        call.resolve(["available": v != nil, "name": v?.name ?? "", "quality": qualityName(v), "lang": v?.language ?? "",
                      "count": AVSpeechSynthesisVoice.speechVoices().count])
    }

    @objc func speak(_ call: CAPPluginCall) {
        let t = call.getString("text") ?? ""
        let l = call.getString("lang") ?? "en-US"
        let r = Float(call.getDouble("rate") ?? 0.9)
        DispatchQueue.main.async {
            self.cancelCurrent()
            guard !t.isEmpty else { call.resolve(); return }
            self.text = t; self.lang = l; self.rate = r; self.notes = []
            self.pending = call
            self.attempt = 0
            self.start(self.bestVoice(l))
        }
    }

    private func start(_ v: AVSpeechSynthesisVoice?) {
        synth.delegate = self
        // Speak on Apple's own system audio channel, not the app's: the web view also uses the app's
        // channel, and changing it (build 111-115) left both Apple's voice and the web voice silent.
        synth.usesApplicationAudioSession = false
        gotStart = false; gotWords = false
        let u = AVSpeechUtterance(string: text)
        u.voice = v
        u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rate))
        u.pitchMultiplier = 1.0
        u.volume = 1.0
        usedVoice = v
        started = false
        token += 1
        let mine = token
        synth.speak(u)
        // safety net: Apple hasn't started speaking within 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.token == mine, !self.started, self.pending != nil else { return }
            self.token += 1
            self.synth.stopSpeaking(at: .immediate)
            self.note(self.usedVoice)
            if self.attempt == 0 {
                self.attempt = 1
                self.start(self.plainVoice(self.lang))
            } else {
                let c = self.pending; self.pending = nil
                c?.reject("silent: " + self.notes.joined(separator: "; "), "SILENT")
            }
        }
    }

    private func cancelCurrent() {
        token += 1
        if synth.isSpeaking || synth.isPaused { synth.stopSpeaking(at: .immediate) }
        if let c = pending { pending = nil; c.resolve(["stopped": true]) }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cancelCurrent()
            call.resolve()
        }
    }

    private func done() {
        guard let c = pending else { return }
        pending = nil
        c.resolve(["voice": usedVoice?.name ?? "", "quality": qualityName(usedVoice), "retried": attempt > 0,
                   "detail": "start:\(gotStart ? "yes" : "no") words:\(gotWords ? "yes" : "no")"])
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.gotStart = true; self.started = true }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.gotWords = true; self.started = true }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard self.started else { return } // a silent run is handled by the safety net
            self.done()
        }
    }
}
