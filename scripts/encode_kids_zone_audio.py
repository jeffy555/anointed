"""Re-encode the Kids Zone background loops from WAV to AAC in an MP4 container.

Two constraints drive the format choice, and both are easy to get wrong:

1. **Not Ogg Vorbis.** It is the obvious pick for looping game audio and it is
   what most advice suggests, but `audioplayers` on iOS is AVAudioPlayer, which
   cannot decode Vorbis. Android would play it and iOS would fail silently.
   AAC-in-M4A is the one good format both platforms decode natively.

2. **Not MP3.** These tracks loop continuously under gameplay. MP3 has encoder
   delay and padding that no container metadata describes, so every loop point
   gets an audible gap. M4A carries an edit list that both platforms honour, so
   it loops far more cleanly.

96 kbps mono is generous for ambient music played at 42% volume; the source is
mono 44.1 kHz, so nothing is being upsampled.
"""
import os
import subprocess
import sys

FFMPEG = sys.argv[1]
SRC_DIR = os.path.join('assets', 'audio', 'kids_zone')
TRACKS = ['anointed_interesting', 'anointed_funky', 'anointed_thrilling']
BITRATE = '96k'

before = after = 0
for name in TRACKS:
    src = os.path.join(SRC_DIR, name + '.wav')
    dst = os.path.join(SRC_DIR, name + '.m4a')
    if not os.path.exists(src):
        print('missing:', src, file=sys.stderr)
        sys.exit(1)

    subprocess.run(
        [FFMPEG, '-y', '-loglevel', 'error',
         '-i', src,
         '-c:a', 'aac', '-b:a', BITRATE, '-ac', '1', '-ar', '44100',
         # Strip cover art / metadata that would only pad the file.
         '-map_metadata', '-1',
         '-movflags', '+faststart',
         dst],
        check=True)

    s, d = os.path.getsize(src), os.path.getsize(dst)
    before += s
    after += d
    print('%-24s %6.2f MB -> %5.2f MB  (%.0f%% smaller)'
          % (name, s / 1048576, d / 1048576, 100 * (1 - d / s)))

print()
print('total %.2f MB -> %.2f MB, saving %.2f MB'
      % (before / 1048576, after / 1048576, (before - after) / 1048576))
