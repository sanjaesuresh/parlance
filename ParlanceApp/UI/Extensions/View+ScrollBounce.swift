import SwiftUI
import UIKit

extension View {
    /// Suppresses horizontal rubber-band on a vertical SwiftUI `ScrollView`.
    /// `scrollBounceBehavior(_:axes:)` cannot reach this because the scroll
    /// view's declared axis is `.vertical` only, yet the underlying
    /// `UIScrollView` produced by `.refreshable` still permits a small
    /// horizontal bounce when dragged sideways.
    func disableHorizontalScrollBounce() -> some View {
        background(ScrollBounceProbe().frame(width: 0, height: 0))
    }
}

private struct ScrollBounceProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let probe = UIView()
        probe.isUserInteractionEnabled = false
        DispatchQueue.main.async { configure(from: probe) }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { configure(from: uiView) }
    }

    private func configure(from view: UIView) {
        var ancestor: UIView? = view.superview
        while let v = ancestor {
            if let scrollView = v as? UIScrollView {
                scrollView.alwaysBounceHorizontal = false
                scrollView.contentSize.width = scrollView.bounds.width
                return
            }
            ancestor = v.superview
        }
    }
}
