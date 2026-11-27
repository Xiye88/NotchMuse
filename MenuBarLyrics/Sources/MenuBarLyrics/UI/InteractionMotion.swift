import AppKit
import QuartzCore

@MainActor
enum InteractionMotion {
    private static func centeredScaleTransform(for layer: CALayer, scale: CGFloat) -> CATransform3D {
        guard scale != 1 else { return CATransform3DIdentity }
        let cx = layer.bounds.midX
        let cy = layer.bounds.midY
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, cx, cy, 0)
        t = CATransform3DScale(t, scale, scale, 1)
        t = CATransform3DTranslate(t, -cx, -cy, 0)
        return t
    }

    static func rebound(_ layer: CALayer?, from scale: CGFloat) {
        guard let layer, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: centeredScaleTransform(for: layer, scale: scale))
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        animation.stiffness = 450
        animation.damping = 27
        animation.duration = animation.settlingDuration
        layer.add(animation, forKey: "interactionRebound")
    }

    static func magnify(_ layer: CALayer?, hovered: Bool) {
        guard let layer else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let targetScale: CGFloat = hovered && !reduceMotion ? 1.08 : 1.0
        let target = centeredScaleTransform(for: layer, scale: targetScale)
        let from = layer.presentation()?.transform ?? layer.transform
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = target
        layer.removeAnimation(forKey: "interactionMagnify")
        if !reduceMotion {
            let animation = CABasicAnimation(keyPath: "transform")
            animation.fromValue = NSValue(caTransform3D: from)
            animation.toValue = NSValue(caTransform3D: target)
            animation.duration = 0.14
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(animation, forKey: "interactionMagnify")
        }
        CATransaction.commit()
    }
}
