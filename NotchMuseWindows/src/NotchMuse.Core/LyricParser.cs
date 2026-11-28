using System.Globalization;
using System.Text.RegularExpressions;

namespace NotchMuse.Core;

public static partial class LyricParser
{
    [GeneratedRegex(@"\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]")]
    private static partial Regex Stamp();
    [GeneratedRegex(@"<(\d{1,3}):(\d{2}(?:\.\d{1,3})?)>")]
    private static partial Regex InlineStamp();
    [GeneratedRegex(@"\[offset:([+-]?\d+)\]", RegexOptions.IgnoreCase)]
    private static partial Regex OffsetTag();
    [GeneratedRegex(@"^\[(\d+),(\d+)\](.*)$")]
    private static partial Regex RichLine();
    [GeneratedRegex(@"<(\d+),(\d+),\d+>([^<]*)")]
    private static partial Regex KrcWord();
    [GeneratedRegex(@"\((\d+),(\d+),\d+\)([^\(]*)")]
    private static partial Regex YrcWord();
    private static double Time(Match m) => double.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) * 60
        + double.Parse(m.Groups[2].Value, CultureInfo.InvariantCulture);

    public static LyricDocument Parse(string text)
    {
        var offsetMatch = OffsetTag().Match(text);
        var offset = offsetMatch.Success ? double.Parse(offsetMatch.Groups[1].Value, CultureInfo.InvariantCulture) / 1000 : 0;
        var lines = new List<LyricLine>();
        foreach (var row in text.Replace("\r", "").Split('\n'))
        {
            var stamps = Stamp().Matches(row);
            if (stamps.Count == 0) continue;
            // Only bracket timestamps preceding the vocal body represent repeated lines.
            var bodyStart = stamps[0].Index + stamps[0].Length;
            var starts = new List<double> { Time(stamps[0]) };
            foreach (Match next in stamps.Cast<Match>().Skip(1))
            {
                if (next.Index != bodyStart) break;
                starts.Add(Time(next)); bodyStart += next.Length;
            }
            var body = row[bodyStart..].Trim();
            var wordStamps = InlineStamp().Matches(body);
            var words = new List<LyricWord>();
            for (var i = 0; i < wordStamps.Count; i++)
            {
                var m = wordStamps[i]; var next = i + 1 < wordStamps.Count ? wordStamps[i + 1] : null;
                var content = body[(m.Index + m.Length)..(next?.Index ?? body.Length)];
                if (content.Length > 0 && next is not null && Time(next) >= Time(m))
                    words.Add(new(Time(m), Time(next), content));
            }
            var plain = InlineStamp().Replace(body, "");
            foreach (var start in starts)
            {
                var delta = start - starts[0];
                var shifted = words.Select(w => w with { Start = w.Start + delta, End = w.End + delta }).ToArray();
                lines.Add(new(start, plain, wordStamps.Count > 1 ? Time(wordStamps[^1]) + delta : null, shifted));
            }
        }
        return new(lines.OrderBy(l => l.Start).ToArray(), offset);
    }

    public static LyricDocument ParseRich(string text, bool krc)
    {
        var lines = new List<LyricLine>();
        foreach (var row in text.Replace("\r", "").Split('\n'))
        {
            var m = RichLine().Match(row);
            if (!m.Success) continue;
            var start = double.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) / 1000;
            var duration = double.Parse(m.Groups[2].Value, CultureInfo.InvariantCulture) / 1000;
            var regex = krc ? KrcWord() : YrcWord();
            var words = regex.Matches(m.Groups[3].Value).Select(w =>
            {
                var s = double.Parse(w.Groups[1].Value, CultureInfo.InvariantCulture) / 1000 + (krc ? start : 0);
                return new LyricWord(s, s + double.Parse(w.Groups[2].Value, CultureInfo.InvariantCulture) / 1000, w.Groups[3].Value);
            }).ToArray();
            if (words.Length > 0)
            {
                // Provider word ends can extend beyond the declared row end. Retain
                // the vocal line and its real starts; malformed rich timing is downgraded.
                var valid = words.All(w => w.Start >= start && w.End >= w.Start && w.End <= start + duration + .002);
                lines.Add(new(start, string.Concat(words.Select(w => w.Text)), start + duration, valid ? words : null));
            }
        }
        return new(lines.OrderBy(l => l.Start).ToArray());
    }
}
