import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';

void main() {
  group('TorrentSource', () {
    test('magnet keeps kind and uppercases the btih hash in label', () {
      const source = TorrentSource.magnet(
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      );
      expect(source.kind, TorrentSourceKind.magnet);
      expect(source.label, 'magnet:0123456789ABCDEF0123456789ABCDEF01234567');
    });

    test('magnet without a valid btih still shows a readable tail', () {
      const source = TorrentSource.magnet('magnet:?xt=urn:btih:short');
      expect(source.kind, TorrentSourceKind.magnet);
      expect(source.label, 'magnet:?xt=urn:btih:short');
    });

    test('file extracts the trailing filename for the label', () {
      const source = TorrentSource.file('/tmp/downloads/ubuntu-24.04.torrent');
      expect(source.kind, TorrentSourceKind.file);
      expect(source.label, 'file: ubuntu-24.04.torrent');
    });

    test('file label handles backslash paths', () {
      const source = TorrentSource.file(r'C:\downloads\debian.torrent');
      expect(source.label, 'file: debian.torrent');
    });
  });
}
