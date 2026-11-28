using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace NotchMuse.App;

public partial class App : System.Windows.Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        RenderOptions.ProcessRenderMode = RenderMode.SoftwareOnly;
        base.OnStartup(e);

        var auditIndex = Array.IndexOf(e.Args, "--audit-screenshots");
        if (auditIndex >= 0 && auditIndex + 1 < e.Args.Length)
        {
            var outputDir = e.Args[auditIndex + 1];
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            try
            {
                await AuditSnapshotRunner.RunAsync(outputDir);
                Shutdown(0);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex);
                Shutdown(1);
            }
            return;
        }

        var main = new MainWindow();
        MainWindow = main;
        main.Show();
    }
}
