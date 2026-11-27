using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace NotchMuse.App;

/// <summary>
/// Bencho-inspired center-symmetrical spring micro-interactions (RenderTransformOrigin = 0.5, 0.5 strictly enforced).
/// Automatically respects Windows reduced-motion / ClientAreaAnimation accessibility setting.
/// </summary>
public static class InteractionMotion
{
    public static bool AnimationsAllowed => SystemParameters.ClientAreaAnimation;

    public static void Rebound(FrameworkElement? element, double fromScale = 0.97)
    {
        if (element is null || !AnimationsAllowed) return;
        var scale = EnsureCenteredScaleTransform(element);

        var animX = new DoubleAnimation(fromScale, 1.0, TimeSpan.FromMilliseconds(210))
        {
            EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.34 }
        };
        var animY = new DoubleAnimation(fromScale, 1.0, TimeSpan.FromMilliseconds(210))
        {
            EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.34 }
        };

        scale.BeginAnimation(ScaleTransform.ScaleXProperty, animX);
        scale.BeginAnimation(ScaleTransform.ScaleYProperty, animY);
    }

    public static void Magnify(FrameworkElement? element, double toScale)
    {
        if (element is null) return;
        var scale = EnsureCenteredScaleTransform(element);

        if (!AnimationsAllowed)
        {
            scale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
            scale.BeginAnimation(ScaleTransform.ScaleYProperty, null);
            scale.ScaleX = toScale;
            scale.ScaleY = toScale;
            return;
        }

        var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
        scale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(toScale, TimeSpan.FromMilliseconds(140)) { EasingFunction = ease });
        scale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(toScale, TimeSpan.FromMilliseconds(140)) { EasingFunction = ease });
    }

    private static ScaleTransform EnsureCenteredScaleTransform(FrameworkElement element)
    {
        // Strictly center-axis symmetrical scaling — never off-corner!
        element.RenderTransformOrigin = new System.Windows.Point(0.5, 0.5);
        if (element.RenderTransform is ScaleTransform existing) return existing;

        if (element.RenderTransform is TransformGroup group)
        {
            var found = group.Children.OfType<ScaleTransform>().FirstOrDefault();
            if (found is not null) return found;
            var added = new ScaleTransform(1, 1);
            group.Children.Add(added);
            return added;
        }

        var st = new ScaleTransform(1, 1);
        element.RenderTransform = st;
        return st;
    }
}
