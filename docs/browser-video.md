# Automatic browser video: Selenium and Cuprite

First backend is Linux X11 capture with FFmpeg x11grab, for **headed** browsers on a dedicated Xvfb display. Driver-independent; it records the entire display, not a browser DOM or a headless browser. No video is captured by default.

Install FFmpeg with libvpx, Xvfb, Chrome and your normal test driver dependencies. Enable an existing reporting adapter (RSpec, Minitest, or Cucumber). Run a dedicated browser-only suite, with one test worker per isolated display:

```bash
xvfb-run -a -s '-screen 0 800x600x24 -nolisten tcp' bash -c '
  export DOMSTRIDE_BROWSER_VIDEO=1
  export DOMSTRIDE_VIDEO_DISPLAY="$DISPLAY"
  export DOMSTRIDE_VIDEO_SIZE=800x600
  bundle exec rspec spec/system
'
```

Configure Selenium/Cuprite to run headed, with the same display dimensions. The adapter starts capture at the framework case boundary, stops/reaps FFmpeg before final metadata write, and attaches the finalized WebM to that case. Skipped/pending cases discard video. Capture failure logs an error class and does not override framework status. Existing explicit Report.capture is unaffected. The feature is enabled per entire test process, not auto detection of browser tests; run nonbrowser tests separately. No change to browser driver options is performed by the adapter.

Capture is bounded to 120 seconds and approximately 7.5 MB, 12 fps, VP8. Longer tests may have truncated video; there is no guarantee of full-length capture. Short tests may yield no usable recording. The display lock prevents overlapping captures within one suite directory; independent suites and workers must have separate displays. No macOS/Windows, remote WebDriver, or true headless capture support in this backend. Do not record a shared desktop: all visible content can be captured. No automatic upload except synthetic CI fixtures. Video seeking alignment remains 010.3. CI checks real headed Selenium and Cuprite with both failed/passed cases and ffprobe decoded frame counts.
