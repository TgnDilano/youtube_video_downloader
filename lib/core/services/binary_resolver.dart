import 'dart:io';

/// Resolves the CLI tools the app drives as external processes
/// (yt-dlp, ffmpeg, ffprobe): bundled with the app first, then well-known
/// developer installs, then the PATH.
class BinaryResolver {
  static Directory? _bundleDir;

  /// Directory containing the running executable: the app bundle's
  /// Contents/MacOS on macOS, the app folder on Windows.
  static Directory? bundleDirectory() {
    if (_bundleDir != null) return _bundleDir;
    final exe = Platform.resolvedExecutable;
    if (exe.isEmpty) return null;
    _bundleDir = File(exe).parent;
    return _bundleDir;
  }

  /// Returns the absolute path of [cmd] when bundled or found in a
  /// well-known install location, otherwise the bare command name so the
  /// shell PATH is used.
  static Future<String> resolve(String cmd) async {
    final exeName = Platform.isWindows ? '$cmd.exe' : cmd;
    final bundle = bundleDirectory();
    if (bundle != null) {
      final bundled = File('${bundle.path}/$exeName');
      if (await bundled.exists()) return bundled.path;
    }
    const installDirs = ['/opt/homebrew/bin', '/usr/local/bin'];
    for (final dir in installDirs) {
      final candidate = File('$dir/$exeName');
      if (await candidate.exists()) return candidate.path;
    }
    return cmd;
  }
}