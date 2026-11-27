using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Automation;
using NotchMuse.App.Themes;

namespace NotchMuse.App.Overlays;

public sealed record TaskbarSlot(
    double Left,
    double Top,
    double Width,
    double Height,
    bool IsLightTaskbar,
    bool IsCenteredTaskbar,
    bool HasLiveTaskbar);

/// <summary>
/// BetterLyrics-inspired Windows 11 taskbar bottom-left blank-zone detector.
/// Combines Shell_TrayWnd geometry, Registry (TaskbarAl / TaskbarDa / SystemUsesLightTheme),
/// and UI Automation child bounds to anchor lyrics cleanly in the centered taskbar's left gap.
/// </summary>
public static class TaskbarLocator
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindowW(string? className, string? windowName);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindowExW(IntPtr parent, IntPtr childAfter, string? className, string? windowName);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hwnd, out NativeRect rect);

    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);

    [StructLayout(LayoutKind.Sequential)]
    private readonly record struct NativeRect(int Left, int Top, int Right, int Bottom);

    public static bool IsCenteredTaskbar()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced");
            if (key?.GetValue("TaskbarAl") is int align) return align != 0;
        }
        catch (UnauthorizedAccessException) { }
        return true; // Windows 11 default is centered
    }

    public static bool IsWidgetsButtonVisible()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced");
            if (key?.GetValue("TaskbarDa") is int widgets) return widgets != 0;
        }
        catch (UnauthorizedAccessException) { }
        return false;
    }

    public static TaskbarSlot Locate()
    {
        var isLight = ThemeManager.IsTaskbarLightTheme();
        var isCentered = IsCenteredTaskbar();
        var widgetsVisible = IsWidgetsButtonVisible();

        var trayHwnd = FindWindowW("Shell_TrayWnd", null);
        if (trayHwnd != IntPtr.Zero && GetWindowRect(trayHwnd, out var trayPx) && trayPx.Right > trayPx.Left && trayPx.Bottom > trayPx.Top)
        {
            var dpi = GetDpiForWindow(trayHwnd);
            var scale = dpi > 0 ? dpi / 96.0 : 1.0;

            var barLeft = trayPx.Left / scale;
            var barTop = trayPx.Top / scale;
            var barWidth = (trayPx.Right - trayPx.Left) / scale;
            var barHeight = Math.Clamp((trayPx.Bottom - trayPx.Top) / scale, 36, 72);

            double? widgetsRightDip = null;
            double? startLeftDip = null;
            double? trayNotifyLeftDip = null;

            var notifyHwnd = FindWindowExW(trayHwnd, IntPtr.Zero, "TrayNotifyWnd", null);
            if (notifyHwnd != IntPtr.Zero && GetWindowRect(notifyHwnd, out var notifyPx) && notifyPx.Left > trayPx.Left)
            {
                trayNotifyLeftDip = notifyPx.Left / scale;
            }

            if (isCentered)
            {
                TryQueryUiaBounds(trayHwnd, scale, barLeft, barWidth, out widgetsRightDip, out startLeftDip);
            }

            return ComputeSlot(
                barLeft,
                barTop,
                barWidth,
                barHeight,
                isCentered,
                widgetsVisible,
                isLight,
                widgetsRightDip,
                startLeftDip,
                trayNotifyLeftDip,
                hasLiveTaskbar: true);
        }

        // Safe fallback using WPF primary screen metrics when taskbar handle is unavailable
        var screenWidth = SystemParameters.PrimaryScreenWidth;
        var screenHeight = SystemParameters.PrimaryScreenHeight;
        var workBottom = SystemParameters.WorkArea.Bottom;
        var fallbackHeight = Math.Clamp(screenHeight - workBottom, 44, 56);
        var fallbackTop = screenHeight - fallbackHeight;

        return ComputeSlot(
            0,
            fallbackTop,
            screenWidth,
            fallbackHeight,
            isCentered,
            widgetsVisible,
            isLight,
            widgetsRightDip: null,
            startLeftDip: null,
            trayNotifyLeftDip: null,
            hasLiveTaskbar: false);
    }

    public static TaskbarSlot ComputeSlot(
        double barLeft,
        double barTop,
        double barWidth,
        double barHeight,
        bool isCentered,
        bool widgetsVisible,
        bool isLightTaskbar,
        double? widgetsRightDip,
        double? startLeftDip,
        double? trayNotifyLeftDip,
        bool hasLiveTaskbar = true)
    {
        if (isCentered)
        {
            // Left anchor: right after Widgets button if present, otherwise crisp 12 DIP left inset
            var safeLeft = widgetsRightDip.HasValue && widgetsRightDip.Value > barLeft + 40 && widgetsRightDip.Value < barLeft + barWidth * 0.28
                ? widgetsRightDip.Value + 10
                : barLeft + (widgetsVisible ? 164 : 12);

            // Right boundary: just before the centered Start button
            var safeRight = startLeftDip.HasValue && startLeftDip.Value > safeLeft + 120
                ? startLeftDip.Value - 14
                : barLeft + barWidth * 0.34;

            var available = Math.Max(0, safeRight - safeLeft);
            var width = Math.Clamp(available, Math.Min(220, Math.Max(140, barWidth * 0.22)), 420);
            if (safeLeft + width > safeRight && available >= 150)
            {
                width = available;
            }

            return new TaskbarSlot(safeLeft, barTop, width, barHeight, isLightTaskbar, true, hasLiveTaskbar);
        }

        // Left-aligned taskbar fallback: anchor cleanly on the right side just before TrayNotifyWnd
        var rightEdge = trayNotifyLeftDip.HasValue && trayNotifyLeftDip.Value > barLeft + 320
            ? trayNotifyLeftDip.Value - 14
            : barLeft + barWidth - 220;
        var leftAlignedWidth = Math.Clamp(barWidth * 0.24, 240, 380);
        var leftAlignedX = Math.Max(barLeft + 260, rightEdge - leftAlignedWidth);
        return new TaskbarSlot(leftAlignedX, barTop, leftAlignedWidth, barHeight, isLightTaskbar, false, hasLiveTaskbar);
    }

    private static void TryQueryUiaBounds(
        IntPtr trayHwnd,
        double scale,
        double barLeft,
        double barWidth,
        out double? widgetsRightDip,
        out double? startLeftDip)
    {
        widgetsRightDip = null;
        startLeftDip = null;

        try
        {
            var root = AutomationElement.FromHandle(trayHwnd);
            if (root is null) return;

            var buttons = root.FindAll(
                TreeScope.Descendants,
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));

            var centerMinX = barLeft + barWidth * 0.20;
            var centerMaxX = barLeft + barWidth * 0.72;
            var earliestCenterX = double.MaxValue;
            var rightmostWidgetX = 0.0;

            for (var i = 0; i < buttons.Count; i++)
            {
                var el = buttons[i];
                var rect = el.Current.BoundingRectangle;
                if (rect.IsEmpty || rect.Width <= 4 || rect.Height <= 4) continue;

                var leftDip = rect.Left / scale;
                var rightDip = rect.Right / scale;
                var autoId = el.Current.AutomationId ?? "";
                var cls = el.Current.ClassName ?? "";

                if (autoId.Contains("Widgets", StringComparison.OrdinalIgnoreCase) ||
                    cls.Contains("Widgets", StringComparison.OrdinalIgnoreCase) ||
                    (leftDip < barLeft + 48 && rightDip < barLeft + 210 && rect.Width / scale > 70))
                {
                    if (rightDip > rightmostWidgetX) rightmostWidgetX = rightDip;
                    continue;
                }

                if (autoId.Equals("StartButton", StringComparison.OrdinalIgnoreCase) ||
                    cls.Contains("ToggleStartMenu", StringComparison.OrdinalIgnoreCase))
                {
                    if (leftDip < earliestCenterX) earliestCenterX = leftDip;
                    continue;
                }

                if (leftDip >= centerMinX && leftDip <= centerMaxX && leftDip < earliestCenterX)
                {
                    earliestCenterX = leftDip;
                }
            }

            if (rightmostWidgetX > barLeft + 30) widgetsRightDip = rightmostWidgetX;
            if (earliestCenterX < double.MaxValue) startLeftDip = earliestCenterX;
        }
        catch (ElementNotAvailableException) { }
        catch (COMException) { }
        catch (InvalidOperationException) { }
    }
}
