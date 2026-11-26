namespace NotchMuse.Core;

public static class VersionComparison
{
    public static int Compare(string current, string latest)
    {
        var left = Parse(current);
        var right = Parse(latest);
        return left.CompareTo(right);
    }

    private static Version Parse(string value)
    {
        var cleaned = value.Trim().TrimStart('v', 'V');
        var dash = cleaned.IndexOf('-');
        if (dash >= 0) cleaned = cleaned[..dash];
        return Version.TryParse(cleaned, out var version) ? version : new Version(0, 0, 0, 0);
    }
}
