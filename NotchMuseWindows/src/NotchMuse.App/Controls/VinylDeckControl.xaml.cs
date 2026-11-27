using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace NotchMuse.App.Controls;

public partial class VinylDeckControl : System.Windows.Controls.UserControl
{
    private bool playing;
    private bool hasTrack;
    private double eqPhase;
    private bool animationsRunning;

    public VinylDeckControl()
    {
        InitializeComponent();
    }

    public void UpdateState(string? title, string? subtitle, bool isPlaying, bool english)
    {
        hasTrack = !string.IsNullOrWhiteSpace(title);
        TitleText.Text = hasTrack ? title! : (english ? "Waiting for music…" : "等待播放音乐…");
        SubtitleText.Text = !string.IsNullOrWhiteSpace(subtitle) ? subtitle! : "NotchMuse Hi-Fi";

        StateText.Text = !hasTrack ? "IDLE" : (isPlaying ? "PLAY" : "PAUSE");
        if (isPlaying)
        {
            StateBadge.SetResourceReference(Border.BackgroundProperty, "AccentSoftBrush");
            StateText.SetResourceReference(TextBlock.ForegroundProperty, "AccentBrush");
            EqBar1.Opacity = 0.95;
            EqBar2.Opacity = 1.0;
            EqBar3.Opacity = 0.88;
        }
        else
        {
            StateBadge.SetResourceReference(Border.BackgroundProperty, "ControlBrush");
            StateText.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondaryBrush");
            EqBar1.Opacity = 0.35;
            EqBar2.Opacity = 0.35;
            EqBar3.Opacity = 0.35;
            EqBar1.Height = 4;
            EqBar2.Height = 7;
            EqBar3.Height = 5;
        }

        if (playing != isPlaying)
        {
            playing = isPlaying;
            AnimateTonearm(isPlaying);
            UpdateDiscSpin(isPlaying);
        }
    }

    public void StepEq(double deltaSeconds)
    {
        if (!playing) return;
        eqPhase += deltaSeconds * 7.5;
        EqBar1.Height = 4 + (Math.Sin(eqPhase) * 0.5 + 0.5) * 8.5;
        EqBar2.Height = 4.5 + (Math.Sin(eqPhase * 1.37 + 1.1) * 0.5 + 0.5) * 8.5;
        EqBar3.Height = 3.5 + (Math.Sin(eqPhase * 0.91 + 2.3) * 0.5 + 0.5) * 8.0;
    }

    public void SetStaticVisualFrame(double discAngle, double bar1, double bar2, double bar3)
    {
        DiscRotation.BeginAnimation(RotateTransform.AngleProperty, null);
        DiscRotation.Angle = discAngle;
        ArmRotation.BeginAnimation(RotateTransform.AngleProperty, null);
        ArmRotation.Angle = playing ? 0 : -22;
        EqBar1.Height = bar1;
        EqBar2.Height = bar2;
        EqBar3.Height = bar3;
    }

    private void AnimateTonearm(bool engaged)
    {
        var anim = new DoubleAnimation(engaged ? 0 : -22, TimeSpan.FromMilliseconds(260))
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };
        ArmRotation.BeginAnimation(RotateTransform.AngleProperty, anim);
    }

    private void UpdateDiscSpin(bool shouldSpin)
    {
        if (shouldSpin && !animationsRunning)
        {
            var start = DiscRotation.Angle % 360;
            var spin = new DoubleAnimation(start, start + 360, TimeSpan.FromSeconds(7.5))
            {
                RepeatBehavior = RepeatBehavior.Forever
            };
            DiscRotation.BeginAnimation(RotateTransform.AngleProperty, spin);
            animationsRunning = true;
        }
        else if (!shouldSpin && animationsRunning)
        {
            var current = DiscRotation.Angle;
            DiscRotation.BeginAnimation(RotateTransform.AngleProperty, null);
            DiscRotation.Angle = current;
            animationsRunning = false;
        }
    }
}
