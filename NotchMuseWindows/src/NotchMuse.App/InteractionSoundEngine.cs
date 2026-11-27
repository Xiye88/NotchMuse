using System.Collections.Concurrent;
using System.IO;
using System.Media;

namespace NotchMuse.App;

public enum InteractionSoundCue
{
    Tick,
    Step,
    Latch,
    Dial,
    Landed,
    Hush
}

/// <summary>
/// Zero-asset restrained in-memory PCM WAV micro-sound synthesizer (1:1 Mac Build 104 acoustic parity).
/// Pre-synthesizes 24kHz 16-bit mono WAV buffers once and plays asynchronously without blocking UI (0% idle CPU).
/// </summary>
public static class InteractionSoundEngine
{
    private const int SampleRate = 24_000;
    private static readonly ConcurrentDictionary<InteractionSoundCue, byte[]> WaveCache = new();
    private static readonly object PlayLock = new();
    private static bool enabled = true;

    public static bool Enabled
    {
        get => enabled;
        set => enabled = value;
    }

    public static double GetCueVolume(InteractionSoundCue cue) => cue switch
    {
        InteractionSoundCue.Tick => 0.25,
        InteractionSoundCue.Step => 0.28,
        InteractionSoundCue.Latch => 0.30,
        InteractionSoundCue.Dial => 0.26,
        InteractionSoundCue.Landed => 0.32,
        InteractionSoundCue.Hush => 0.22,
        _ => 0.25
    };

    public static void Play(InteractionSoundCue cue)
    {
        if (!enabled) return;
        Enqueue(cue);
    }

    public static void SetEnabledWithFeedback(bool nextEnabled)
    {
        if (enabled == nextEnabled) return;
        enabled = nextEnabled;
        // Play tick when turning ON, soft hush when turning OFF
        Enqueue(nextEnabled ? InteractionSoundCue.Tick : InteractionSoundCue.Hush);
    }

    public static byte[] SynthesizeWave(InteractionSoundCue cue) =>
        WaveCache.GetOrAdd(cue, BuildWaveBytes);

    private static void Enqueue(InteractionSoundCue cue)
    {
        var bytes = SynthesizeWave(cue);
        _ = Task.Run(() =>
        {
            lock (PlayLock)
            {
                try
                {
                    using var ms = new MemoryStream(bytes, writable: false);
                    using var player = new SoundPlayer(ms);
                    player.Play();
                }
                catch (InvalidOperationException) { }
                catch (TimeoutException) { }
                catch (IOException) { }
            }
        });
    }

    private static byte[] BuildWaveBytes(InteractionSoundCue cue)
    {
        (double StartHz, double EndHz, double DurationSec)[] tones = cue switch
        {
            InteractionSoundCue.Tick => [(560, 380, 0.032)],
            InteractionSoundCue.Step => [(380, 240, 0.048)],
            InteractionSoundCue.Latch => [(315, 260, 0.026), (510, 400, 0.032)],
            InteractionSoundCue.Dial => [(820, 1040, 0.030)],
            InteractionSoundCue.Landed => [(660, 660, 0.039), (880, 880, 0.060)],
            InteractionSoundCue.Hush => [(330, 247, 0.080)],
            _ => [(560, 380, 0.032)]
        };

        var counts = tones.Select(t => Math.Max(2, (int)(t.DurationSec * SampleRate))).ToArray();
        var totalSamples = counts.Sum();
        var pcmSize = totalSamples * sizeof(short);
        var volume = GetCueVolume(cue);

        using var ms = new MemoryStream(44 + pcmSize);
        using var bw = new BinaryWriter(ms);

        // Standard RIFF/WAVE PCM header (44 bytes)
        bw.Write("RIFF"u8);
        bw.Write(36 + pcmSize);
        bw.Write("WAVE"u8);
        bw.Write("fmt "u8);
        bw.Write(16); // Subchunk1Size for PCM
        bw.Write((ushort)1); // AudioFormat = PCM
        bw.Write((ushort)1); // NumChannels = Mono
        bw.Write(SampleRate);
        bw.Write(SampleRate * sizeof(short)); // ByteRate
        bw.Write((ushort)sizeof(short)); // BlockAlign
        bw.Write((ushort)16); // BitsPerSample
        bw.Write("data"u8);
        bw.Write(pcmSize);

        for (var i = 0; i < tones.Length; i++)
        {
            var (startHz, endHz, _) = tones[i];
            var count = counts[i];
            for (var n = 0; n < count; n++)
            {
                var t = (double)n / SampleRate;
                var progress = (double)n / (count - 1);
                var phase = 2.0 * Math.PI * t * (startHz + (endHz - startHz) * progress * 0.5);
                var envelope = Math.Min(1.0, t / 0.003) * Math.Pow(1.0 - progress, 2.0);
                var sample = Math.Sin(phase) * envelope * 0.38 * volume * short.MaxValue;
                bw.Write((short)Math.Clamp(Math.Round(sample), short.MinValue, short.MaxValue));
            }
        }

        return ms.ToArray();
    }
}
