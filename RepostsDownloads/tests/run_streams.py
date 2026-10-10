#!/usr/bin/env python3
"""Exercise the production argument builder against real multi-variant HLS."""
import json
import functools
import http.server
import pathlib
import subprocess
import tempfile
import threading
ROOT = pathlib.Path(__file__).resolve().parent

def run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode(errors="replace"))
        raise

with tempfile.TemporaryDirectory(prefix="xsuixin-stream-test-") as directory:
    work = pathlib.Path(directory)
    cli = work / "arguments"
    run(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework", "Foundation",
         str(ROOT / "StreamArgumentsCLI.m"), str(ROOT.parent / "BHRDStreamArguments.m"), "-o", str(cli)])
    for label, size in [("low", "160x90"), ("high", "320x180")]:
        run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", f"testsrc2=size={size}:rate=10",
             "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", "1", "-c:v", "libx264",
             "-preset", "ultrafast", "-c:a", "aac", "-hls_time", "1", "-hls_playlist_type", "vod", str(work / f"{label}.m3u8")])
    master = work / "master.m3u8"
    master.write_text("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=120000,RESOLUTION=160x90\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=320x180\nhigh.m3u8\n")
    class SilentHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args): pass
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(SilentHandler, directory=str(work)))
    thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
    try:
        probe_args = json.loads(run([str(cli), "--probe", f"http://127.0.0.1:{server.server_port}/master.m3u8"]))
        streams = json.loads(run(["ffprobe", *probe_args]))["streams"]
        assert any(s["codec_type"] == "audio" for s in streams)
    finally:
        server.shutdown(); server.server_close(); thread.join()
    videos = [s for s in streams if s["codec_type"] == "video"]
    assert len(videos) == 2
    for stream in videos:
        output = work / f'output {stream["index"]}.mp4'
        args = json.loads(run([str(cli), master.as_uri(), str(stream["index"]), str(output)]))
        run(["ffmpeg", "-v", "error", *args])
        result = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(output)]))["streams"]
        video = next(s for s in result if s["codec_type"] == "video")
        assert (video["width"], video["height"], video["codec_name"]) == (stream["width"], stream["height"], stream["codec_name"])
        assert any(s["codec_type"] == "audio" for s in result)
        # HLS Annex-B and MP4 AVC packet framing differ; decoded frames must remain identical.
        def frames(source, index):
            data = run(["ffmpeg", "-v", "error", "-i", str(source), "-map", f"0:{index}", "-f", "framemd5", "-"]).decode()
            return [line.rsplit(",", 1)[-1].strip() for line in data.splitlines() if not line.startswith("#")]
        assert frames(master, stream["index"]) == frames(output, video["index"])
    print("PASS: production HTTP probe returns both real HLS qualities and audio; downloads retain selected resolution and decoded frames")
