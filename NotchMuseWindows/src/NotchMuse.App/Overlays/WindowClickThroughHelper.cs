using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace NotchMuse.App.Overlays;

/// <summary>
/// 64-bit safe Win32 extended window style helper for click-through overlays.
/// Guarantees WS_EX_LAYERED + WS_EX_NOACTIVATE + WS_EX_TOOLWINDOW and exact flipping
/// of WS_EX_TRANSPARENT with SWP_FRAMECHANGED so hit-testing updates immediately.
/// </summary>
public static class WindowClickThroughHelper
{
    public const int GwlExStyle = -20;
    public const long WsExTransparent = 0x00000020L;
    public const long WsExToolWindow = 0x00000080L;
    public const long WsExLayered = 0x00080000L;
    public const long WsExNoActivate = 0x08000000L;

    private const uint SwpNoSize = 0x0001;
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;

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

    public static long ApplyClickThrough(IntPtr hwnd, bool locked)
    {
        if (hwnd == IntPtr.Zero) return 0;
        var current = GetExStyle(hwnd);
        var next = ComputeOverlayExStyle(current, locked);
        SetExStyle(hwnd, next);
        SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0,
            SwpNoMove | SwpNoSize | SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
        return GetExStyle(hwnd);
    }

    public static long ApplyClickThrough(Window window, bool locked)
    {
        var hwnd = new WindowInteropHelper(window).Handle;
        return ApplyClickThrough(hwnd, locked);
    }
}
