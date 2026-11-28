using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NotchMuse.App;

/// <summary>
/// Compact zero-dependency ISO/IEC 18004 QR Code Version 3-M encoder (29x29 modules,
/// 44 data codewords + 26 Reed-Solomon EC codewords, holds up to 42 UTF-8 bytes —
/// exact fit for EVM 0x... and TRON T... wallet addresses) with pixel-sharp WPF rendering.
/// </summary>
public static class QrCodeRenderer
{
    private const int Size = 29; // Version 3 = 4*3 + 17
    private const int DataCodewords = 44; // Version 3-M
    private const int EcCodewords = 26;   // Version 3-M

    // Precomputed BCH(15,5) format strings for Error Correction Level M (bits 00) and masks 0..7
    private static readonly int[] FormatBitsM =
    [
        0x5412, 0x5125, 0x5E7C, 0x5B4B, 0x45F9, 0x40CE, 0x4F97, 0x4AA0
    ];

    public static bool[,] EncodeVersion3M(string payload)
    {
        var bytes = Encoding.UTF8.GetBytes(payload);
        if (bytes.Length > 42)
            throw new ArgumentException("Payload exceeds Version 3-M byte capacity (42 bytes).", nameof(payload));

        var data = BuildDataCodewords(bytes);
        var ec = ComputeReedSolomon(data, EcCodewords);
        var allCodewords = new byte[DataCodewords + EcCodewords];
        Array.Copy(data, 0, allCodewords, 0, DataCodewords);
        Array.Copy(ec, 0, allCodewords, DataCodewords, EcCodewords);

        var baseModules = new bool[Size, Size];
        var isFunction = new bool[Size, Size];
        DrawFunctionPatterns(baseModules, isFunction);
        PlaceCodewords(baseModules, isFunction, allCodewords);

        var bestPenalty = int.MaxValue;
        bool[,]? bestMatrix = null;
        for (var mask = 0; mask < 8; mask++)
        {
            var candidate = ApplyMask(baseModules, isFunction, mask);
            DrawFormatBits(candidate, FormatBitsM[mask]);
            var penalty = ComputePenalty(candidate);
            if (penalty < bestPenalty)
            {
                bestPenalty = penalty;
                bestMatrix = candidate;
            }
        }
        return bestMatrix!;
    }

    public static BitmapSource RenderBitmap(string payload, int pixelSize = 180)
    {
        var matrix = EncodeVersion3M(payload);
        const int quiet = 3;
        var totalModules = Size + quiet * 2;
        var scale = Math.Max(2, pixelSize / totalModules);
        var imgSize = totalModules * scale;

        var pixels = new byte[imgSize * imgSize * 4];
        for (var i = 0; i < pixels.Length; i += 4)
        {
            pixels[i] = 255;     // B
            pixels[i + 1] = 255; // G
            pixels[i + 2] = 255; // R
            pixels[i + 3] = 255; // A
        }

        for (var y = 0; y < Size; y++)
        {
            for (var x = 0; x < Size; x++)
            {
                if (!matrix[y, x]) continue;
                var px0 = (x + quiet) * scale;
                var py0 = (y + quiet) * scale;
                for (var dy = 0; dy < scale; dy++)
                {
                    var rowOffset = (py0 + dy) * imgSize * 4;
                    for (var dx = 0; dx < scale; dx++)
                    {
                        var idx = rowOffset + (px0 + dx) * 4;
                        pixels[idx] = 26;
                        pixels[idx + 1] = 26;
                        pixels[idx + 2] = 28;
                        pixels[idx + 3] = 255;
                    }
                }
            }
        }

        var bmp = BitmapSource.Create(imgSize, imgSize, 96, 96, PixelFormats.Bgra32, null, pixels, imgSize * 4);
        bmp.Freeze();
        return bmp;
    }

    private static byte[] BuildDataCodewords(byte[] payload)
    {
        var bits = new List<int>(DataCodewords * 8);
        AppendBits(bits, 0b0100, 4);           // Byte mode
        AppendBits(bits, payload.Length, 8);   // Character count (V1-V9 = 8 bits)
        foreach (var b in payload) AppendBits(bits, b, 8);

        var maxBits = DataCodewords * 8;
        var terminator = Math.Min(4, maxBits - bits.Count);
        AppendBits(bits, 0, terminator);
        while (bits.Count % 8 != 0) bits.Add(0);

        var padBytes = new byte[] { 0xEC, 0x11 };
        var padIdx = 0;
        while (bits.Count < maxBits)
        {
            AppendBits(bits, padBytes[padIdx++ & 1], 8);
        }

        var result = new byte[DataCodewords];
        for (var i = 0; i < DataCodewords; i++)
        {
            var val = 0;
            for (var b = 0; b < 8; b++) val = (val << 1) | bits[i * 8 + b];
            result[i] = (byte)val;
        }
        return result;
    }

    private static void AppendBits(List<int> bits, int value, int count)
    {
        for (var i = count - 1; i >= 0; i--)
            bits.Add((value >> i) & 1);
    }

    private static byte[] ComputeReedSolomon(byte[] data, int ecCount)
    {
        var gen = new byte[ecCount + 1];
        gen[0] = 1;
        byte root = 1;
        for (var i = 0; i < ecCount; i++)
        {
            for (var j = i + 1; j >= 1; j--)
                gen[j] = (byte)(GfMultiply(gen[j], root) ^ gen[j - 1]);
            gen[0] = GfMultiply(gen[0], root);
            root = GfMultiply(root, 2);
        }

        // Standard descending-degree polynomial coefficients
        var divisor = new byte[ecCount];
        for (var i = 0; i < ecCount; i++) divisor[i] = gen[ecCount - 1 - i];

        var rem = new byte[ecCount];
        foreach (var b in data)
        {
            var factor = (byte)(b ^ rem[0]);
            Array.Copy(rem, 1, rem, 0, ecCount - 1);
            rem[ecCount - 1] = 0;
            for (var j = 0; j < ecCount; j++)
                rem[j] ^= GfMultiply(divisor[j], factor);
        }
        return rem;
    }

    private static byte GfMultiply(byte a, byte b)
    {
        var res = 0;
        for (var i = 0; i < 8; i++)
        {
            if ((b & 1) != 0) res ^= a;
            var hi = (a & 0x80) != 0;
            a = (byte)(a << 1);
            if (hi) a ^= 0x1D;
            b >>= 1;
        }
        return (byte)res;
    }

    private static void DrawFunctionPatterns(bool[,] m, bool[,] fn)
    {
        // Timing patterns
        for (var i = 0; i < Size; i++)
        {
            SetFn(m, fn, 6, i, (i & 1) == 0);
            SetFn(m, fn, i, 6, (i & 1) == 0);
        }

        // Three 7x7 finder patterns + 1px white separators
        DrawFinder(m, fn, 0, 0);
        DrawFinder(m, fn, Size - 7, 0);
        DrawFinder(m, fn, 0, Size - 7);

        // Version 3 single alignment pattern centered at (22, 22)
        for (var dy = -2; dy <= 2; dy++)
        {
            for (var dx = -2; dx <= 2; dx++)
            {
                var dist = Math.Max(Math.Abs(dx), Math.Abs(dy));
                SetFn(m, fn, 22 + dx, 22 + dy, dist != 1);
            }
        }

        // Reserve format info areas & fixed dark module at (8, 21)
        for (var i = 0; i <= 8; i++)
        {
            if (i != 6) { fn[8, i] = true; fn[i, 8] = true; }
        }
        for (var i = 0; i < 8; i++)
        {
            fn[8, Size - 1 - i] = true;
            fn[Size - 1 - i, 8] = true;
        }
        SetFn(m, fn, 8, Size - 8, true); // Dark module
    }

    private static void DrawFinder(bool[,] m, bool[,] fn, int x0, int y0)
    {
        for (var dy = -1; dy <= 7; dy++)
        {
            for (var dx = -1; dx <= 7; dx++)
            {
                var x = x0 + dx;
                var y = y0 + dy;
                if (x < 0 || x >= Size || y < 0 || y >= Size) continue;
                var dark = dx is >= 0 and <= 6 && dy is >= 0 and <= 6 &&
                           (dx is 0 or 6 || dy is 0 or 6 || (dx is >= 2 and <= 4 && dy is >= 2 and <= 4));
                SetFn(m, fn, x, y, dark);
            }
        }
    }

    private static void SetFn(bool[,] m, bool[,] fn, int x, int y, bool dark)
    {
        m[y, x] = dark;
        fn[y, x] = true;
    }

    private static void PlaceCodewords(bool[,] m, bool[,] fn, byte[] codewords)
    {
        var bitIdx = 0;
        var totalBits = codewords.Length * 8;
        var upward = true;
        for (var right = Size - 1; right >= 1; right -= 2)
        {
            if (right == 6) right = 5; // Skip vertical timing column
            for (var step = 0; step < Size; step++)
            {
                var y = upward ? Size - 1 - step : step;
                for (var col = 0; col < 2; col++)
                {
                    var x = right - col;
                    if (fn[y, x]) continue;
                    var dark = false;
                    if (bitIdx < totalBits)
                    {
                        dark = ((codewords[bitIdx >> 3] >> (7 - (bitIdx & 7))) & 1) != 0;
                        bitIdx++;
                    }
                    m[y, x] = dark;
                }
            }
            upward = !upward;
        }
    }

    private static bool[,] ApplyMask(bool[,] baseModules, bool[,] fn, int mask)
    {
        var result = (bool[,])baseModules.Clone();
        for (var y = 0; y < Size; y++)
        {
            for (var x = 0; x < Size; x++)
            {
                if (fn[y, x]) continue;
                var invert = mask switch
                {
                    0 => ((x + y) & 1) == 0,
                    1 => (y & 1) == 0,
                    2 => x % 3 == 0,
                    3 => (x + y) % 3 == 0,
                    4 => ((y / 2 + x / 3) & 1) == 0,
                    5 => (x * y) % 2 + (x * y) % 3 == 0,
                    6 => (((x * y) % 2 + (x * y) % 3) & 1) == 0,
                    _ => (((x + y) % 2 + (x * y) % 3) & 1) == 0
                };
                if (invert) result[y, x] = !result[y, x];
            }
        }
        return result;
    }

    private static void DrawFormatBits(bool[,] m, int format)
    {
        // Bit 14 is MSB, Bit 0 is LSB
        int Bit(int idx) => (format >> idx) & 1;

        for (var i = 0; i <= 5; i++) m[8, i] = Bit(14 - i) != 0;
        m[8, 7] = Bit(8) != 0;
        m[8, 8] = Bit(7) != 0;
        m[7, 8] = Bit(6) != 0;
        for (var i = 0; i <= 5; i++) m[5 - i, 8] = Bit(5 - i) != 0;

        for (var i = 0; i < 8; i++) m[8, Size - 1 - i] = Bit(i) != 0;
        for (var i = 0; i < 7; i++) m[Size - 1 - i, 8] = Bit(14 - i) != 0;
    }

    private static int ComputePenalty(bool[,] m)
    {
        var penalty = 0;
        // Rule 1: runs of 5+ identical modules in rows & cols
        for (var y = 0; y < Size; y++)
        {
            var runLen = 1;
            for (var x = 1; x < Size; x++)
            {
                if (m[y, x] == m[y, x - 1]) { runLen++; if (runLen == 5) penalty += 3; else if (runLen > 5) penalty++; }
                else runLen = 1;
            }
        }
        for (var x = 0; x < Size; x++)
        {
            var runLen = 1;
            for (var y = 1; y < Size; y++)
            {
                if (m[y, x] == m[y - 1, x]) { runLen++; if (runLen == 5) penalty += 3; else if (runLen > 5) penalty++; }
                else runLen = 1;
            }
        }
        // Rule 2: 2x2 blocks
        for (var y = 0; y < Size - 1; y++)
            for (var x = 0; x < Size - 1; x++)
                if (m[y, x] == m[y, x + 1] && m[y, x] == m[y + 1, x] && m[y, x] == m[y + 1, x + 1])
                    penalty += 3;
        return penalty;
    }
}
