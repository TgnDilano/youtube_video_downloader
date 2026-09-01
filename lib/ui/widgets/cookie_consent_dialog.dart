import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/app_theme.dart';

/// Ask the user before granting yt-dlp access to a browser whose cookie store
/// sits behind macOS Keychain encryption (Chrome / Edge / Brave).
///
/// Returns `true` when the user understands and allows the access, `false`
/// when they prefer to skip cookies entirely.
Future<bool> showCookieConsentDialog(
  BuildContext context,
  String browserName,
) async {
  final granted = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => CookieConsentDialog(browserName: browserName),
  );
  return granted ?? false;
}

class CookieConsentDialog extends StatelessWidget {
  final String browserName;

  const CookieConsentDialog({super.key, required this.browserName});

  @override
  Widget build(BuildContext context) {
    final browser = _displayName(browserName);
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BROWSER ACCESS CONSENT',
                    style: TText.mono(
                      context,
                      size: 10.5,
                      letterSpacing: 0.18,
                      color: TColors.amber,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use your $browser login for downloads?',
                    style: TText.display(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConsentLine(
                    icon: Icons.lyrics_outlined,
                    color: TColors.green,
                    text:
                        'Some YouTube videos (e.g. the 27-hour Unity course) '
                        'reply\n"HTTP 403: Forbidden" to anonymous requests. '
                        'Signing in\ndownloads them properly.',
                  ),
                  const SizedBox(height: 10),
                  _ConsentLine(
                    icon: Icons.manage_search,
                    color: TColors.amber,
                    text: 'What is read: ONLY YouTube cookies from $browser.\n'
                        'NOT passwords. NOT autofill. NOT history.',
                  ),
                  const SizedBox(height: 10),
                  _ConsentLine(
                    icon: Icons.shield_outlined,
                    color: TColors.red,
                    text:
                        'Nothing leaves your machine except the download\n'
                        'request sent to YouTube itself.',
                  ),
                  const SizedBox(height: 10),
                  _ConsentLine(
                    icon: Icons.key_outlined,
                    color: TColors.textMuted,
                    text:
                        'macOS will then ask to unlock your Keychain entry\n'
                        'named "$browser Safe Storage". Choose "Always Allow".',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: TColors.textDim,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will only be asked once. You can always change '
                      'the source or disable it in Settings.',
                      style: TText.mono(
                        context,
                        size: 9.5,
                        color: TColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: TColors.line),
                        ),
                        child: Center(
                          child: Text(
                            'SKIP — NO COOKIES',
                            style: TText.mono(
                              context,
                              size: 11,
                              color: TColors.textDim,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: TColors.green.withValues(alpha: 0.12),
                          border: Border.all(
                            color: TColors.green.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'ALLOW ACCESS',
                            style: TText.mono(
                              context,
                              size: 11,
                              color: TColors.green,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayName(String value) {
    switch (value) {
      case 'chrome':
        return 'Chrome';
      case 'edge':
        return 'Edge';
      case 'brave':
        return 'Brave';
      default:
        return value;
    }
  }
}

class _ConsentLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ConsentLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: TColors.jackBg,
            border: Border.all(color: TColors.line),
          ),
          child: Center(child: Icon(icon, size: 13, color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TText.mono(
              context,
              size: 11,
              color: TColors.textMuted,
            ).copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}