using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;

namespace NotchMuse.App.Controls;

/// <summary>
/// Centered lyric row with true glyph-clipped left-to-right color sweep (zero horizontal bar)
/// and silky opacity + subtle vertical glide transitions — ZERO abrupt font-size scaling jump!
/// </summary>
public sealed class SweepLyricLineControl : Border
{
    private readonly Grid sweepHost = new();
    private readonly TextBlock basePrimary = new();
    private readonly TextBlock sweepPrimary = new();
    private readonly RectangleGeometry sweepClip = new();
    private readonly TextBlock translationBlock = new();
    private readonly Border timePill = new();
    private readonly TextBlock timeText = new();
    private readonly TranslateTransform glideTransform = new();

    private double sweepProgress;
    private int distanceFromActive = 99;
    private double baseFontSize = 22;
    private bool wasActive;

    public double StartTime { get; }
    public string PrimaryText { get; }
    public string? TranslationText { get; }

    public event Action<double>? SeekRequested;

    public SweepLyricLineControl(double startTime, string primaryText, string? translationText, bool showBilingual)
    {
        StartTime = startTime;
        PrimaryText = string.IsNullOrWhiteSpace(primaryText) ? "♪" : primaryText;
        TranslationText = translationText;

        CornerRadius = new CornerRadius(12);
        // Constant uniform padding prevents any layout-reflow vertical jump on line transitions!
        Padding = new Thickness(24, 12, 24, 12);
        Margin = new Thickness(12, 3, 12, 3);
        Background = System.Windows.Media.Brushes.Transparent;
        Cursor = System.Windows.Input.Cursors.Hand;
        RenderTransform = glideTransform;

        var root = new Grid();

        var textStack = new StackPanel
        {
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(34, 0, 34, 0)
        };

        basePrimary.Text = PrimaryText;
        basePrimary.TextAlignment = TextAlignment.Center;
        basePrimary.TextWrapping = TextWrapping.Wrap;
        basePrimary.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimaryBrush");

        sweepPrimary.Text = PrimaryText;
        sweepPrimary.TextAlignment = TextAlignment.Center;
        sweepPrimary.TextWrapping = TextWrapping.Wrap;
        sweepPrimary.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
        sweepPrimary.Clip = sweepClip;
        sweepPrimary.Visibility = Visibility.Collapsed;

        sweepHost.HorizontalAlignment = System.Windows.HorizontalAlignment.Center;
        sweepHost.Children.Add(basePrimary);
        sweepHost.Children.Add(sweepPrimary);
        sweepHost.SizeChanged += (_, _) => UpdateClipGeometry();
        textStack.Children.Add(sweepHost);

        translationBlock.Text = translationText ?? "";
        translationBlock.TextAlignment = TextAlignment.Center;
        translationBlock.TextWrapping = TextWrapping.Wrap;
        translationBlock.Margin = new Thickness(0, 5, 0, 0);
        translationBlock.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
        translationBlock.Visibility = showBilingual && !string.IsNullOrWhiteSpace(translationText)
            ? Visibility.Visible
            : Visibility.Collapsed;
        textStack.Children.Add(translationBlock);

        // Hover MM:SS Timestamp Pill on the right
        timeText.Text = FormatTimestamp(startTime);
        timeText.FontSize = 10.5;
        timeText.FontWeight = FontWeights.Medium;
        timeText.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");

        timePill.CornerRadius = new CornerRadius(6);
        timePill.Padding = new Thickness(7, 2.5, 7, 2.5);
        timePill.HorizontalAlignment = System.Windows.HorizontalAlignment.Right;
        timePill.VerticalAlignment = VerticalAlignment.Center;
        timePill.SetResourceReference(Border.BackgroundProperty, "ControlBrush");
        timePill.Child = timeText;
        timePill.Opacity = 0;
        timePill.IsHitTestVisible = false;

        root.Children.Add(textStack);
        root.Children.Add(timePill);
        Child = root;

        MouseEnter += (_, _) =>
        {
            SetResourceReference(Border.BackgroundProperty, "HoverRowBrush");
            timePill.Opacity = 1;
        };
        MouseLeave += (_, _) =>
        {
            Background = System.Windows.Media.Brushes.Transparent;
            timePill.Opacity = 0;
        };
        MouseLeftButtonUp += (_, e) =>
        {
            e.Handled = true;
            SeekRequested?.Invoke(StartTime);
        };

        ApplyVisualState(99, 0, 22, null, 1.0, animate: false);
    }

    public void SetShowBilingual(bool showBilingual)
    {
        translationBlock.Visibility = showBilingual && !string.IsNullOrWhiteSpace(TranslationText)
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    public void ApplyVisualState(int distance, double progress, double activeFontSize, System.Windows.Media.Brush? customAccentBrush, double lyricOpacity, bool animate = true)
    {
        distanceFromActive = distance;
        sweepProgress = Math.Clamp(progress, 0, 1);
        baseFontSize = Math.Clamp(activeFontSize, 14, 34);

        var isActive = distance == 0;

        // Uniform stable font size across all lines eliminates jarring block-scaling jumps!
        // Visual hierarchy is expressed purely through crisp glyph sweep, weight, and smooth opacity/glide.
        var stablePrimarySize = Math.Max(15, baseFontSize * 0.92);
        var stableSubSize = Math.Max(11.5, stablePrimarySize * 0.62);
        var weight = isActive ? FontWeights.Bold : FontWeights.Medium;

        basePrimary.FontSize = stablePrimarySize;
        basePrimary.FontWeight = weight;
        sweepPrimary.FontSize = stablePrimarySize;
        sweepPrimary.FontWeight = weight;
        translationBlock.FontSize = stableSubSize;

        var duration = TimeSpan.FromMilliseconds(220);
        var ease = new CubicEase { EasingMode = EasingMode.EaseOut };

        if (isActive)
        {
            sweepPrimary.Visibility = Visibility.Visible;
            if (customAccentBrush is not null)
                sweepPrimary.Foreground = customAccentBrush;
            else
                sweepPrimary.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");

            var glowColor = customAccentBrush switch
            {
                SolidColorBrush scb => System.Windows.Media.Color.FromArgb(62, scb.Color.R, scb.Color.G, scb.Color.B),
                LinearGradientBrush lgb when lgb.GradientStops.Count > 0 => System.Windows.Media.Color.FromArgb(62, lgb.GradientStops[0].Color.R, lgb.GradientStops[0].Color.G, lgb.GradientStops[0].Color.B),
                _ => System.Windows.Media.Color.FromArgb(62, 224, 109, 27)
            };
            sweepPrimary.Effect = new DropShadowEffect
            {
                Color = glowColor,
                BlurRadius = 10,
                ShadowDepth = 0,
                Opacity = 0.42
            };

            AnimateOpacity(basePrimary, 0.36 * lyricOpacity, animate, duration, ease);
            AnimateOpacity(sweepPrimary, lyricOpacity, animate, duration, ease);
            AnimateOpacity(translationBlock, 0.86 * lyricOpacity, animate, duration, ease);

            if (animate && !wasActive)
            {
                glideTransform.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(3.5, 0, TimeSpan.FromMilliseconds(240)) { EasingFunction = ease });
            }
            else if (!animate)
            {
                glideTransform.BeginAnimation(TranslateTransform.YProperty, null);
                glideTransform.Y = 0;
            }
        }
        else
        {
            var fade = distance switch
            {
                1 => 0.56,
                2 => 0.36,
                3 => 0.25,
                _ => 0.18
            };
            sweepPrimary.Visibility = Visibility.Collapsed;
            sweepPrimary.Effect = null;

            AnimateOpacity(basePrimary, fade * lyricOpacity, animate, duration, ease);
            AnimateOpacity(translationBlock, fade * 0.78 * lyricOpacity, animate, duration, ease);
            if (!animate)
            {
                glideTransform.BeginAnimation(TranslateTransform.YProperty, null);
                glideTransform.Y = 0;
            }
        }

        wasActive = isActive;
        UpdateClipGeometry();
    }

    private static void AnimateOpacity(UIElement target, double to, bool animate, TimeSpan duration, IEasingFunction ease)
    {
        if (animate)
        {
            target.BeginAnimation(OpacityProperty, new DoubleAnimation(to, duration) { EasingFunction = ease });
        }
        else
        {
            target.BeginAnimation(OpacityProperty, null);
            target.Opacity = to;
        }
    }

    public void UpdateSweepProgress(double progress)
    {
        if (distanceFromActive != 0) return;
        sweepProgress = Math.Clamp(progress, 0, 1);
        UpdateClipGeometry();
    }

    private void UpdateClipGeometry()
    {
        if (distanceFromActive != 0) return;
        var width = sweepHost.ActualWidth;
        var height = sweepHost.ActualHeight;
        if (width <= 0 || height <= 0)
        {
            sweepHost.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
            width = sweepHost.DesiredSize.Width;
            height = sweepHost.DesiredSize.Height;
        }
        sweepClip.Rect = new Rect(0, 0, Math.Max(0, width * sweepProgress), Math.Max(48, height + 12));
    }

    private static string FormatTimestamp(double seconds)
    {
        var clamped = Math.Max(0, seconds);
        var ts = TimeSpan.FromSeconds(clamped);
        return string.Format(CultureInfo.InvariantCulture, "{0:00}:{1:00}", (int)ts.TotalMinutes, ts.Seconds);
    }
}
