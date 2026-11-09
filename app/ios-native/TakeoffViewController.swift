// The app's main screen: Capacitor's normal web view, plus the app's own native pieces.
import UIKit
import Capacitor

class TakeoffViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(TakeoffSpeechPlugin())
    }
}
