import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/download/domain/download_controller.dart';

void main() {
  Map format(int height, {int? size, String vcodec = 'avc1', String acodec = 'none'}) {
    final map = <String, Object?>{
      'height': height,
      'vcodec': vcodec,
      'acodec': acodec,
    };
    if (size != null) map['filesize_approx'] = size;
    return map;
  }

  Map<String, dynamic> info({
    List<Map>? formats,
    int? topLevel,
  }) {
    final map = <String, dynamic>{'formats': formats ?? []};
    if (topLevel != null) map['filesize'] = topLevel;
    return map;
  }

  test('estimateSizeForResolution sums best video + audio at height', () {
    final i = info(formats: [
      format(1080, size: 2000),
      format(720, size: 1000),
      format(360, size: 400),
      format(720, vcodec: 'none', acodec: 'mp4a', size: 200),
    ]);

    // 1080p: 1080 video (2000) + audio (200).
    expect(DownloadController.estimateSizeForResolution(i, '1080'), 2200);
    // 720p: 720 video (1000) + audio (200) — NOT the 1080 stream.
    expect(DownloadController.estimateSizeForResolution(i, '720'), 1200);
    // best: uses the tallest video stream available.
    expect(DownloadController.estimateSizeForResolution(i, 'best'), 2200);
    // audio: audio-only stream only.
    expect(DownloadController.estimateSizeForResolution(i, 'audio'), 200);
  });

  test('estimateSizeForResolution ignores unknown sizes and empty lists',
      () {
    final i = info(formats: [
      format(1080), // no size
      format(720, vcodec: 'none', acodec: 'mp4a', size: 0),
    ]);
    expect(DownloadController.estimateSizeForResolution(i, 'best'), isNull);

    expect(
      DownloadController.estimateSizeForResolution(info(formats: []), 'best'),
      isNull,
    );
    expect(
      DownloadController.estimateSizeForResolution(
        info(formats: []),
        '720',
      ),
      isNull,
    );
  });

  test('formatBytes renders MiB/GiB like yt-dlp', () {
    expect(DownloadController.formatBytes(0), '');
    expect(DownloadController.formatBytes(500), '500B');
    expect(
      DownloadController.formatBytes(104857600),
      '100.00MiB',
    );
    expect(DownloadController.formatBytes(2147483648), '2.00GiB');
  });
}