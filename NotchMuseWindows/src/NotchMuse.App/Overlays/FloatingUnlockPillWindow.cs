using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;

namespace NotchMuse.App.Overlays;

/// <summary>
/// Compact 28x28 icon-only 🔒 unlock pill displayed directly above (or below near screen top)
/// the locked FreeFloat lyric capsule on cursor hover — matching Mac Build 108 parity.
/// Strictly non-activating (WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW) and clickable while the
/// main lyric overlay remains 100% click-through (WS_EX_TRANSPARENT).
/// </summary>
public sealed class FloatingUnlockPillWindow : Window
{
    private readonly System.Windows.Controls.Button unlockBtn;
    private IntPtr handle;
    private HwndSource? hwndSource;

    public event Action? UnlockRequested;

    public FloatingUnlockPillWindow()
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = System.Windows.Media.Brushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        ResizeMode = ResizeMode.NoResize;
        ShowActivated = false;
        Width = 34;
        Height = 34;
        FocusVisualStyle = null;

        var lockIcon = new System.Windows.Shapes.Path
        {
            Data = Geometry.Parse("M 4.5,7 V 5.2 A 3.5,3.5 0 0 1 11.5,5.2 V 7 M 3.2,7 H 12.8 A 1.2,1.2 0 0 1 14,8.2 V 13.3 A 1.2,1.2 0 0 1 12.8,14.5 H 3.2 A 1.2,1.2 0 0 1 2,13.3 V 8.2 A 1.2,1.2 0 0 1 3.2,7 Z"),
            Stroke = new SolidColorBrush(System.Windows.Media.Color.FromRgb(245, 244, 240)),
            StrokeThickness = 1.45,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            StrokeLineJoin = PenLineJoin.Round,
            Width = 13,
            Height = 13,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        var pill = new Border
        {
            Width = 28,
            Height = 28,
            CornerRadius = new CornerRadius(14),
            Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(236, 25, 25, 31)),
            BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(72, 255, 255, 255)),
            BorderThickness = new Thickness(1),
            HorizontalAlignment = System.Windows.HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Child = lockIcon,
            Effect = new System.Windows.Media.Effects.DropShadowEffect
            {
                Color = Colors.Black,
                BlurRadius = 10,
                ShadowDepth = 2,
                Opacity = 0.36
            }
        };

        unlockBtn = new System.Windows.Controls.Button
        {
            OverridesDefaultStyle = true,
            Background = System.Windows.Media.Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = System.Windows.Input.Cursors.Hand,
            Focusable = false,
            FocusVisualStyle = null,
            ToolTip = "解锁位置 (Ctrl+Alt+L)",
            Content = pill
        };
        unlockBtn.Template = CreateCleanButtonTemplate();
        unlockBtn.MouseEnter += (_, _) =>
        {
            pill.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(200, 255, 138, 54));
            InteractionMotion.Magnify(pill, 1.08);
        };
        unlockBtn.MouseLeave += (_, _) =>
        {
            pill.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(72, 255, 255, 255));
            InteractionMotion.Magnify(pill, 1.0);
        };
        unlockBtn.Click += (_, _) =>
        {
            InteractionSoundEngine.Play(InteractionSoundCue.Latch);
            UnlockRequested?.Invoke();
        };

        Content = unlockBtn;

        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            if (handle != IntPtr.Zero)
            {
                hwndSource = HwndSource.FromHwnd(handle);
                hwndSource?.AddHook(WndProc);
                WindowClickThroughHelper.ApplyClickThrough(handle, locked: false);
            }
        };
        Closed += (_, _) =>
        {
            hwndSource?.RemoveHook(WndProc);
            hwndSource = null;
        };
    }

    public void ApplyLanguage(bool english)
    {
        unlockBtn.ToolTip = english ? "Unlock Position (Ctrl+Alt+L)" : "解锁位置 (Ctrl+Alt+L)";
    }

    public void ShowAt(double leftDip, double topDip)
    {
        Left = leftDip;
        Top = topDip;
        WindowClickThroughHelper.ShowTopmostNoActivate(this, locked: false);
    }

    private static ControlTemplate CreateCleanButtonTemplate()
    {
        var template = new ControlTemplate(typeof(System.Windows.Controls.Button));
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(HorizontalAlignmentProperty, System.Windows.HorizontalAlignment.Center);
        presenter.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        template.VisualTree = presenter;
        return template;
    }

    private static IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WindowClickThroughHelper.WmMouseActivate)
        {
            handled = true;
            return WindowClickThroughHelper.MaNoActivate;
        }
        return IntPtr.Zero;
    }
}
