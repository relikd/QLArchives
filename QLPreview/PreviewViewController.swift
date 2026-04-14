import Cocoa
import Quartz

enum QLPluginError: Error {
	case unsupported
}

// TODO: button to launch companion app (security doesnt allow to launch another app) :-(

class PreviewViewController: ArchiveController, QLPreviewingController {
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	override func loadView() {
		super.loadView()
		// Technically works, but NSOpenPanel popup opens in the background and is hidden by the Quicklook preview.
		// And `.runModal()` does not allow to write files in selected directory.
		btnExtractAll.removeFromSuperview()
		
		// too fiddly in preview. Yes, its somewhat usable in fullscreen but has too many bugs.
		// e.g.
		// - First click inside of search field will place the curser but wont accept input. You have to tab-into the field instead.
		// - Escaping out of the preview is also hard. Only one of the three focus responders will exit.
		// - Any double-click (e.g. column fit-size) will launch the default app (unarchiver).
		// - Clicks are very slowly processed -> each click waits for a double-click event and only if that doesnt happen, it'll performs the actual click
		searchField.isHidden = true
//		searchField.placeholderString = "Search in fullscreen"
	}
	
	func preparePreviewOfFile(at url: URL) async throws {
		if !load(url) {
			throw QLPluginError.unsupported
		}
	}
}
