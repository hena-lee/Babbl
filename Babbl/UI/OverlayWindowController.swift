import Cocoa
import SwiftUI

final class OverlayWindowController {
    private var panel: NSPanel?

    func show<V: View>(rootView: V) {
        if let existing = panel {
            let hostingView = NSHostingView(rootView: rootView)
            existing.contentView = hostingView

            // Resize panel to fit new content
            let fittingSize = hostingView.fittingSize
            let currentFrame = existing.frame
            let newX = currentFrame.midX - fittingSize.width / 2
            existing.setFrame(
                NSRect(x: newX, y: currentFrame.origin.y, width: fittingSize.width, height: fittingSize.height),
                display: true,
                animate: false
            )
            return
        }

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden

        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)

        // Position: bottom center, above the Dock
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - fittingSize.width / 2
            let y = screenFrame.minY + 16
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }

        self.panel = panel
    }

    func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
        })
    }
}
