using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace NotchMuse.App.Overlays;

[StructLayout(LayoutKind.Sequential)]
public struct NativeWindowRect
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential)]
public struct NativePoint
{
    public int X;
    public int Y;
}

public readonly record struct SnapRectResult(NativeWindowRect Rect, bool SnappedCenterX, bool SnappedEdge);

/// <summary>
/// 64-bit safe Win32 extended window style, click-through hit-test, direct physical-pixel drag,
/// and magnetic snap helper for NotchMuse overlays.
/// </summary>
public static class WindowClickThroughHelper
{
    public const int GwlExStyle = -20;
    public const long WsExTransparent = 0x00000020L;
    public const long WsExToolWindow = 0x00000080L;
    public const long WsExLayered = 0x00080000L;
    public const long WsExNoActivate = 0x08000000L;

    public const int WmMouseActivate = 0x0021;
    public const int WmNcHitTest = 0x0084;

    public static readonly IntPtr HtTransparent = new(-1);
    public static readonly IntPtr MaNoActivate = new(3);

    private const uint SwpNoSize = 0x0001;
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;
    private const int SwShowNoActivate = 4;
    private const int VkLButton = 0x01;
    private const int VkRButton = 0x02;
    private const int VkMenu = 0x12;
    private const int SmSwapButton = 23;
    private static readonly IntPtr HwndTopmost = new(-1);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hwnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out NativePoint pt);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out NativeWindowRect rect);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hwnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hwnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hwnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hwnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

    public static bool IsLeftMouseButtonDown()
    {
        var primaryVk = GetSystemMetrics(SmSwapButton) != 0 ? VkRButton : VkLButton;
        return (GetAsyncKeyState(primaryVk) & 0x8000) != 0;
    }
    public static bool IsAltKeyDown() => (GetAsyncKeyState(VkMenu) & 0x8000) != 0;

    public static void MoveWindowPixelsNoActivate(IntPtr hwnd, int leftPx, int topPx)
    {
        if (hwnd == IntPtr.Zero) return;
        _ = SetWindowPos(hwnd, IntPtr.Zero, leftPx, topPx, 0, 0, SwpNoSize | SwpNoZOrder | SwpNoActivate);
    }

    public static long GetExStyle(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return 0;
        return IntPtr.Size == 8
            ? GetWindowLongPtr64(hwnd, GwlExStyle).ToInt64()
            : GetWindowLong32(hwnd, GwlExStyle);
    }

    public static void SetExStyle(IntPtr hwnd, long exStyle)
    {
        if (hwnd == IntPtr.Zero) return;
        if (IntPtr.Size == 8)
            _ = SetWindowLongPtr64(hwnd, GwlExStyle, new IntPtr(exStyle));
        else
            _ = SetWindowLong32(hwnd, GwlExStyle, unchecked((int)exStyle));
    }

    public static long ComputeOverlayExStyle(long currentExStyle, bool locked)
    {
        var baseStyle = currentExStyle | WsExToolWindow | WsExNoActivate | WsExLayered;
        return locked
            ? (baseStyle | WsExTransparent)
            : (baseStyle & ~WsExTransparent);
    }

    public static bool HasTransparentFlag(long exStyle) => (exStyle & WsExTransparent) != 0;

    /// <summary>
    /// Secondary WndProc click-through guard: returns HTTRANSPARENT (-1) on WM_NCHITTEST
    /// whenever locked is true.
    /// </summary>
    public static IntPtr HandleClickThroughMessage(int message, bool locked, ref bool handled)
    {
        if (locked && message == WmNcHitTest)
        {
            handled = true;
            return HtTransparent;
        }
        return IntPtr.Zero;
    }

    /// <summary>
    /// Applies Mac FreeLyricsSnap-parity magnetic center and edge snapping to a native Win32 window RECT,
    /// using the exact same work-area containment bounds as window restore so drops never jump on reopen.
    /// Hold Alt to bypass magnetic snapping cleanly.
    /// </summary>
    public static SnapRectResult SnapFreeWindowRect(
        NativeWindowRect current,
        NativeWindowRect workArea,
        int snapThresholdPx,
        int edgeInsetPx,
        bool altBypass)
    {
        var width = current.Right - current.Left;
        var height = current.Bottom - current.Top;

        var left = current.Left;
        var top = current.Top;
        var snappedCenterX = false;
        var snappedEdge = false;

        if (!altBypass && snapThresholdPx > 0)
        {
            var centerLeft = workArea.Left + (workArea.Right - workArea.Left - width) / 2;
            var leftEdge = workArea.Left + edgeInsetPx;
            var rightEdge = workArea.Right - width - edgeInsetPx;
            var topEdge = workArea.Top + edgeInsetPx;
            var bottomEdge = workArea.Bottom - height - edgeInsetPx;

            if (Math.Abs(left - centerLeft) <= snapThresholdPx)
            {
                left = centerLeft;
                snappedCenterX = true;
            }
            else if (Math.Abs(left - leftEdge) <= snapThresholdPx)
            {
                left = leftEdge;
                snappedEdge = true;
            }
            else if (Math.Abs(left - rightEdge) <= snapThresholdPx)
            {
                left = rightEdge;
                snappedEdge = true;
            }

            if (Math.Abs(top - topEdge) <= snapThresholdPx)
            {
                top = topEdge;
                snappedEdge = true;
            }
            else if (Math.Abs(top - bottomEdge) <= snapThresholdPx)
            {
                top = bottomEdge;
                snappedEdge = true;
            }
        }

        // Exact containment matching PositionOnScreen restore bounds (zero jump on reopen!)
        var maxLeft = Math.Max(workArea.Left, workArea.Right - width);
        var maxTop = Math.Max(workArea.Top, workArea.Bottom - height);
        left = Math.Clamp(left, workArea.Left, maxLeft);
        top = Math.Clamp(top, workArea.Top, maxTop);

        return new SnapRectResult(
            new NativeWindowRect
            {
                Left = left,
                Top = top,
                Right = left + width,
                Bottom = top + height
            },
            snappedCenterX,
            snappedEdge);
    }

    public static long ApplyClickThrough(IntPtr hwnd, bool locked)
    {
        if (hwnd == IntPtr.Zero) return 0;
        var current = GetExStyle(hwnd);
        var next = ComputeOverlayExStyle(current, locked);
        SetExStyle(hwnd, next);
        _ = SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0,
            SwpNoMove | SwpNoSize | SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
        return GetExStyle(hwnd);
    }

    public static long ApplyClickThrough(Window window, bool locked)
    {
        var hwnd = new WindowInteropHelper(window).Handle;
        return ApplyClickThrough(hwnd, locked);
    }

    /// <summary>
    /// Displays an overlay window strictly without stealing activation or pushing MainWindow behind other apps.
    /// </summary>
    public static void ShowTopmostNoActivate(Window overlay, bool locked)
    {
        overlay.ShowActivated = false;
        if (!overlay.IsVisible)
        {
            overlay.Show();
        }
        var hwnd = new WindowInteropHelper(overlay).Handle;
        if (hwnd == IntPtr.Zero) return;
        ApplyClickThrough(hwnd, locked);
        ShowWindow(hwnd, SwShowNoActivate);
        _ = SetWindowPos(hwnd, HwndTopmost, 0, 0, 0, 0, SwpNoMove | SwpNoSize | SwpNoActivate);
    }
}
