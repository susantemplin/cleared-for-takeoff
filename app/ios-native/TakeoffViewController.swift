// The app's main screen: Capacitor's normal web view.
// The speech piece is normally registered through capacitor.config.json (packageClassList, added by
// scripts/add-native.rb); this registers it as a backup only if that didn't happen.
import UIKit
import Capacitor

class TakeoffViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        TakeoffSpeechPlugin.setUpAudio()
        if bridge?.plugin(withName: "TakeoffSpeech") == nil {
            bridge?.registerPluginInstance(TakeoffSpeechPlugin())
        }
    }
}
