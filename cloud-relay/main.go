// babytrack-relay: WebSocket ingest + media fan-out for the BabyTrack camera.
//
// ── Architecture ─────────────────────────────────────────────────────────────
//
//	ESP32  --WSS binary frames-->  relay :8765  /ingest/{id}
//
//	relay serves on :8766
//	  /mjpeg/{id}   MJPEG          (internal — consumed by this relay's ffmpeg)
//	  /audio/{id}   streaming WAV  (internal — consumed by this relay's ffmpeg)
//	  /av/{id}      Matroska H264+Opus   <-- go2rtc pulls this
//	  /speak/{id}   PTT PCM ingress from the Flutter app
//	  /health
//
//	relay spawns ONE ffmpeg per device:
//	  mjpeg + wav  ->  H.264 + Opus  ->  matroska on stdout  ->  /av/{id}
//
//	go2rtc source (registered once per device, never removed):
//	  ffmpeg:http://127.0.0.1:8766/av/{id}#video=copy#audio=copy
//
// ── Why this shape ───────────────────────────────────────────────────────────
//
// go2rtc refuses "exec:" and RTSP-publish producers created through its HTTP
// API ("streams: source from insecure producer"), and a PUT replaces the
// stream's single source rather than adding to it. A stream can therefore only
// ever have ONE API-created producer, so video and audio must arrive already
// muxed together. This relay owns the muxing ffmpeg itself, which also gives it
// direct control over GOP and latency flags, and lets it keep ffmpeg alive
// across ESP32 reconnects instead of tearing the pipeline down every time the
// device blips.
//
// Three properties are load-bearing and must not be regressed:
//
//  1. The WebSocket reader never blocks. Frames are handed off with dropSend,
//     which discards the oldest queued frame rather than waiting for a reader.
//     Any blocking here becomes TCP backpressure on the ESP32, which aborts its
//     socket after a send timeout.
//  2. The go2rtc stream is registered once and never deregistered, and ffmpeg
//     is kept running across device reconnects. Re-registering restarts ffmpeg
//     (~2.5 s), which is longer than a typical reconnect gap.
//  3. The media handlers wait for the first frame instead of returning 404, and
//     keep serving the last frame after the device drops, so a viewer sees a
//     held frame rather than a black screen.
//
// Frame types from the ESP32 (first byte of each binary WS message):
//
//	0x56  JPEG video frame
//	0x41  PCM audio chunk (16 kHz mono int16)
//
// Frames to the ESP32:
//
//	0x53  PCM audio for speaker playback (push-to-talk)
package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	frameTypeVideo = 0x56
	frameTypeAudio = 0x41
	frameTypeSpeak = 0x53

	mjpegBoundary = "BabyTrackFrame"

	audioSampleRate = 16000
	audioChannels   = 1
	audioBitsPer    = 16

	// Drop-oldest channel depths keep latency low. Video depth 2 means a
	// consumer always gets a recent frame rather than one from 100 ms ago;
	// audio depth 8 smooths ~256 ms of jitter without adding audible delay.
	videoChanDepth = 2
	audioChanDepth = 24

	// How long a media handler waits for the device's first frame before
	// giving up. ffmpeg holds its connection open for this long instead of
	// getting a 404 and entering a retry backoff.
	firstFrameWait = 120 * time.Second

	// ffmpeg is restarted no more often than this if it keeps exiting.
	ffmpegRestartDelay = 2 * time.Second
)

var (
	relayToken = mustEnv("RELAY_TOKEN")
	go2rtcURL  = envOrDefault("GO2RTC_URL", "http://127.0.0.1:1984")
	wsPort     = envOrDefault("WS_PORT", "8765")
	httpPort   = envOrDefault("HTTP_PORT", "8766")
	ffmpegBin  = envOrDefault("FFMPEG_BIN", "ffmpeg")

	// Both listeners bind to loopback only. nginx terminates TLS and proxies
	// /ingest/, /speak/ and /audio/ to them, so nothing is lost — but the
	// media endpoints stop being reachable from the internet directly.
	//
	// They previously bound to every interface, which meant /mjpeg/, /audio/
	// and /av/ were served unauthenticated on a public port to anyone who knew
	// a device id. The host has no firewall (ufw inactive, iptables policy
	// ACCEPT with no rules), so the cloud security group was the only thing
	// standing in the way. For a camera pointed at a baby that is not a margin
	// worth relying on.
	bindAddr = envOrDefault("BIND_ADDR", "127.0.0.1")
)

// tokenOK reports whether a request carries the shared relay token.
func tokenOK(r *http.Request) bool {
	return r.URL.Query().Get("token") == relayToken
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("required env var %s not set", key)
	}
	return v
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// ── Per-device state ─────────────────────────────────────────────────────────

type streamState struct {
	id string

	mu        sync.Mutex
	wsConn    *websocket.Conn // device socket, for PTT; nil when disconnected
	lastFrame []byte          // most recent JPEG, held after disconnect
	haveFrame bool
	connected bool

	videoCh chan []byte
	audioCh chan []byte

	// firstFrame is closed once the device has delivered a frame, releasing
	// any media handlers that are waiting to start their response.
	firstFrame chan struct{}
	regOnce    sync.Once // guards go2rtc registration

	// avReaders counts live /av/ requests, each of which owns one ffmpeg.
	avMu      sync.Mutex
	avReaders int
}

var (
	streamsMu sync.Mutex
	streams   = map[string]*streamState{}
)

func getOrCreate(id string) *streamState {
	streamsMu.Lock()
	defer streamsMu.Unlock()
	if st, ok := streams[id]; ok {
		return st
	}
	st := &streamState{
		id:         id,
		videoCh:    make(chan []byte, videoChanDepth),
		audioCh:    make(chan []byte, audioChanDepth),
		firstFrame: make(chan struct{}),
	}
	streams[id] = st
	return st
}

// dropSend hands b to ch without ever blocking. When ch is full the oldest
// item is discarded so fresh media always wins over stale queued media.
//
// This function must remain non-blocking in all paths: it is called from the
// WebSocket read loop, and any stall here propagates to the ESP32 as TCP
// backpressure.
func dropSend(ch chan []byte, b []byte) {
	select {
	case ch <- b:
		return
	default:
	}
	select {
	case <-ch:
	default:
	}
	select {
	case ch <- b:
	default:
	}
}

func (st *streamState) markFrame(frame []byte) {
	st.mu.Lock()
	st.lastFrame = frame
	first := !st.haveFrame
	st.haveFrame = true
	st.mu.Unlock()
	if first {
		close(st.firstFrame)
	}
}

func (st *streamState) snapshot() ([]byte, bool) {
	st.mu.Lock()
	defer st.mu.Unlock()
	return st.lastFrame, st.haveFrame
}

// waitFirstFrame blocks until the device has produced a frame, the request is
// cancelled, or the wait budget expires.
func (st *streamState) waitFirstFrame(ctx context.Context) bool {
	select {
	case <-st.firstFrame:
		return true
	default:
	}
	select {
	case <-st.firstFrame:
		return true
	case <-ctx.Done():
		return false
	case <-time.After(firstFrameWait):
		return false
	}
}

// ── go2rtc registration ──────────────────────────────────────────────────────

// registerStream points go2rtc at this relay's muxed /av/ endpoint. It runs
// once per device for the lifetime of the process: go2rtc keeps the producer
// definition, and re-registering would restart ffmpeg on every device blip.
func (st *streamState) registerStream() {
	st.regOnce.Do(func() {
		src := fmt.Sprintf("ffmpeg:http://127.0.0.1:%s/av/%s#video=copy#audio=copy",
			httpPort, st.id)
		apiURL := fmt.Sprintf("%s/api/streams?name=%s&src=%s",
			go2rtcURL, url.QueryEscape(st.id), url.QueryEscape(src))

		req, err := http.NewRequest(http.MethodPut, apiURL, nil)
		if err != nil {
			log.Printf("[go2rtc] build request for %s failed: %v", st.id, err)
			return
		}
		client := &http.Client{Timeout: 5 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			log.Printf("[go2rtc] register %s failed: %v", st.id, err)
			return
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			log.Printf("[go2rtc] register %s rejected: HTTP %d %s",
				st.id, resp.StatusCode, strings.TrimSpace(string(body)))
			return
		}
		log.Printf("[go2rtc] registered %s -> /av/%s (video+audio)", st.id, st.id)
	})
}

// ── Muxing ffmpeg ────────────────────────────────────────────────────────────

// The transcoder is started per /av/ request rather than kept running.
//
// Matroska writes its EBML header once, at the start of the stream. An earlier
// design ran one long-lived ffmpeg and fanned its stdout out to whoever was
// connected, which meant any consumer that attached after the first byte
// received a headless stream: ffprobe reported "EBML header parsing failed" and
// go2rtc could not open the producer at all. go2rtc attaches lazily — only once
// a viewer appears — so it was always late, and the viewer path never worked.
//
// Giving each /av/ reader its own ffmpeg makes a complete, parseable stream true
// by construction. In practice there is exactly one such reader per device
// (go2rtc), and it holds the connection for as long as any viewer is watching,
// so this is one process per active camera, not one per viewer.
//
// It also means no encoder runs while nobody is watching, which matters for a
// product where most cameras are idle most of the time.
//
// The GOP is set explicitly in the arguments below. go2rtc silently discards
// "#output_args=..." on a source URL, so keyframe interval can only be
// controlled by owning the ffmpeg invocation.

func (st *streamState) ffmpegArgs() []string {
	return []string{
		"-hide_banner", "-loglevel", "error",
		"-fflags", "nobuffer", "-flags", "low_delay",

		// Video: MJPEG pulled from this relay.
		// Setting -framerate 11 tells FFmpeg that each incoming frame represents
		// 1/11th second (~91ms), matching the ESP32 camera capture cadence (~11 fps).
		// Without this, FFmpeg defaults to 25 fps, advancing stream time at only
		// 11/25 = 0.44x speed, which caused audio/video desync and massive growing lag.
		"-thread_queue_size", "512",
		"-framerate", "11",
		"-analyzeduration", "0",
		"-probesize", "32768",
		"-f", "mjpeg",
		"-i", fmt.Sprintf("http://127.0.0.1:%s/mjpeg/%s", httpPort, st.id),

		// Audio: streaming WAV pulled from this relay.
		"-thread_queue_size", "512",
		"-i", fmt.Sprintf("http://127.0.0.1:%s/audio/%s?token=%s",
			httpPort, st.id, url.QueryEscape(relayToken)),

		// H.264 tuned for a live call: no B-frames, keyframe every 1 second
		"-c:v", "libx264",
		"-preset", "ultrafast",
		"-tune", "zerolatency",
		"-profile:v", "baseline",
		"-pix_fmt", "yuv420p",
		"-r", "11",
		"-g", "11",
		"-bf", "0",

		"-c:a", "libopus",
		"-b:a", "24k",
		"-ar", "48000",
		"-ac", "1",
		"-af", "aresample=async=1:min_hard_comp=0.100000:first_pts=0",

		// -flush_packets & -muxdelay 0 prevent muxer from buffering
		"-f", "matroska",
		"-live", "1",
		"-flush_packets", "1",
		"-muxdelay", "0",
		"-max_delay", "0",
		"pipe:1",
	}
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

// ── WebSocket ingest ─────────────────────────────────────────────────────────

var upgrader = websocket.Upgrader{
	CheckOrigin:     func(r *http.Request) bool { return true },
	ReadBufferSize:  8 * 1024,
	WriteBufferSize: 8 * 1024,
}

func ingestHandler(w http.ResponseWriter, r *http.Request) {
	streamID := pathID(r.URL.Path, "/ingest/")
	if streamID == "" {
		http.Error(w, "missing stream_id", http.StatusBadRequest)
		return
	}
	if r.URL.Query().Get("token") != relayToken {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ws] upgrade error for %s: %v", streamID, err)
		return
	}
	defer conn.Close()

	st := getOrCreate(streamID)
	st.mu.Lock()
	prev := st.wsConn
	st.wsConn = conn
	st.connected = true
	st.mu.Unlock()

	// A reconnect can arrive before the old socket's read loop has noticed
	// the drop. Close the stale one so it does not linger.
	if prev != nil && prev != conn {
		prev.Close()
	}

	log.Printf("[ws] device connected: %s", streamID)

	// Register the go2rtc stream once and never withdraw it — see the header
	// note on property 2. The encoder itself is started per viewer by
	// avHandler, so nothing is spun up here for a camera nobody is watching.
	st.registerStream()

	defer func() {
		st.mu.Lock()
		if st.wsConn == conn {
			st.wsConn = nil
			st.connected = false
		}
		st.mu.Unlock()
		log.Printf("[ws] device disconnected: %s (stream stays live)", streamID)
	}()

	var (
		videoFrames uint64
		audioChunks uint64
		videoBytes  uint64
		lastLog     = time.Now()
	)

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			if !websocket.IsCloseError(err,
				websocket.CloseNormalClosure,
				websocket.CloseGoingAway) {
				log.Printf("[ws] read error for %s: %v", streamID, err)
			}
			return
		}
		if len(msg) < 2 {
			continue
		}

		// gorilla reuses msg after ReadMessage returns, so the payload has
		// to be copied before it leaves this loop.
		payload := make([]byte, len(msg)-1)
		copy(payload, msg[1:])

		switch msg[0] {
		case frameTypeVideo:
			st.markFrame(payload)
			dropSend(st.videoCh, payload)
			videoFrames++
			videoBytes += uint64(len(payload))
		case frameTypeAudio:
			dropSend(st.audioCh, payload)
			audioChunks++
		default:
			log.Printf("[ws] unknown frame 0x%02x from %s len=%d",
				msg[0], streamID, len(msg))
		}

		if since := time.Since(lastLog); since >= 30*time.Second {
			secs := since.Seconds()
			avg := 0
			if videoFrames > 0 {
				avg = int(videoBytes / videoFrames)
			}
			log.Printf("[ws] %s: %.1f fps, avg frame %d B, %.0f kbps, %d audio chunks",
				streamID, float64(videoFrames)/secs, avg,
				float64(videoBytes)*8/secs/1000, audioChunks)
			videoFrames, audioChunks, videoBytes = 0, 0, 0
			lastLog = time.Now()
		}
	}
}

// ── MJPEG endpoint (consumed by this relay's ffmpeg) ─────────────────────────

func mjpegHandler(w http.ResponseWriter, r *http.Request) {
	streamID := pathID(r.URL.Path, "/mjpeg/")
	if streamID == "" {
		http.Error(w, "missing stream_id", http.StatusBadRequest)
		return
	}
	st := getOrCreate(streamID)
	ctx := r.Context()

	// Wait for the device rather than 404ing: ffmpeg keeps this connection
	// open instead of failing and backing off.
	if !st.waitFirstFrame(ctx) {
		http.Error(w, "no active stream", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "multipart/x-mixed-replace; boundary="+mjpegBoundary)
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(http.StatusOK)
	flusher, _ := w.(http.Flusher)

	writeFrame := func(frame []byte) error {
		var buf bytes.Buffer
		fmt.Fprintf(&buf, "--%s\r\nContent-Type: image/jpeg\r\nContent-Length: %d\r\n\r\n",
			mjpegBoundary, len(frame))
		buf.Write(frame)
		buf.WriteString("\r\n")
		if _, err := w.Write(buf.Bytes()); err != nil {
			return err
		}
		if flusher != nil {
			flusher.Flush()
		}
		return nil
	}

	if frame, ok := st.snapshot(); ok {
		if writeFrame(frame) != nil {
			return
		}
	}

	for {
		select {
		case <-ctx.Done():
			return

		case frame := <-st.videoCh:
			if writeFrame(frame) != nil {
				return
			}

		case <-time.After(time.Second):
			// Device is quiet or briefly away. Re-send the held frame so
			// ffmpeg's timeline keeps advancing and the viewer sees a
			// frozen picture rather than a stalled stream.
			frame, ok := st.snapshot()
			if !ok {
				continue
			}
			if writeFrame(frame) != nil {
				return
			}
		}
	}
}

// ── Audio endpoint (streaming WAV, consumed by this relay's ffmpeg) ──────────

// wavHeader builds a RIFF header with unknown-length sizes, which ffmpeg
// accepts for an open-ended stream and uses to detect rate, channels and depth.
func wavHeader() []byte {
	const unknown = 0xFFFFFFFF
	byteRate := audioSampleRate * audioChannels * audioBitsPer / 8
	blockAlign := audioChannels * audioBitsPer / 8

	h := make([]byte, 0, 44)
	h = append(h, "RIFF"...)
	h = binary.LittleEndian.AppendUint32(h, unknown)
	h = append(h, "WAVEfmt "...)
	h = binary.LittleEndian.AppendUint32(h, 16)
	h = binary.LittleEndian.AppendUint16(h, 1) // PCM
	h = binary.LittleEndian.AppendUint16(h, audioChannels)
	h = binary.LittleEndian.AppendUint32(h, audioSampleRate)
	h = binary.LittleEndian.AppendUint32(h, uint32(byteRate))
	h = binary.LittleEndian.AppendUint16(h, uint16(blockAlign))
	h = binary.LittleEndian.AppendUint16(h, audioBitsPer)
	h = append(h, "data"...)
	h = binary.LittleEndian.AppendUint32(h, unknown)
	return h
}

func audioHandler(w http.ResponseWriter, r *http.Request) {
	streamID := pathID(r.URL.Path, "/audio/")
	if streamID == "" {
		http.Error(w, "missing stream_id", http.StatusBadRequest)
		return
	}
	// This is the one media endpoint nginx proxies to the public internet, so
	// it is the one that has to authenticate. The app already sends this token
	// (mic_audio_service.dart) — it simply was not being checked, which left
	// live microphone audio from the room readable by anyone who knew a device
	// id. /mjpeg/ and /av/ are not proxied and now bind to loopback only.
	if !tokenOK(r) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}
	st := getOrCreate(streamID)
	ctx := r.Context()

	w.Header().Set("Content-Type", "audio/wav")
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(http.StatusOK)
	flusher, _ := w.(http.Flusher)

	if _, err := w.Write(wavHeader()); err != nil {
		return
	}
	if flusher != nil {
		flusher.Flush()
	}

	// 32 ms of silence at 16 kHz mono, used to keep ffmpeg's audio clock
	// moving while the device is silent or away.
	silence := make([]byte, audioSampleRate*audioChannels*(audioBitsPer/8)*64/1000)

	for {
		var chunk []byte
		select {
		case <-ctx.Done():
			return
		case chunk = <-st.audioCh:
		case <-time.After(300 * time.Millisecond):
			chunk = silence
		}
		if _, err := w.Write(chunk); err != nil {
			return
		}
		if flusher != nil {
			flusher.Flush()
		}
	}
}

// ── Muxed A/V endpoint (consumed by go2rtc) ──────────────────────────────────

func avHandler(w http.ResponseWriter, r *http.Request) {
	streamID := pathID(r.URL.Path, "/av/")
	if streamID == "" {
		http.Error(w, "missing stream_id", http.StatusBadRequest)
		return
	}
	st := getOrCreate(streamID)
	ctx := r.Context()

	// Wait for the device before spawning an encoder, so ffmpeg is not started
	// against endpoints that have nothing to give it yet.
	if !st.waitFirstFrame(ctx) {
		http.Error(w, "no active stream", http.StatusNotFound)
		return
	}

	cmd := exec.CommandContext(ctx, ffmpegBin, st.ffmpegArgs()...)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("[ff] %s stdout pipe: %v", st.id, err)
		http.Error(w, "transcoder unavailable", http.StatusInternalServerError)
		return
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Start(); err != nil {
		log.Printf("[ff] %s start failed: %v", st.id, err)
		http.Error(w, "transcoder unavailable", http.StatusInternalServerError)
		return
	}
	log.Printf("[ff] %s transcoder started for viewer (pid %d)", st.id, cmd.Process.Pid)

	st.avMu.Lock()
	st.avReaders++
	st.avMu.Unlock()

	defer func() {
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		_ = cmd.Wait()
		st.avMu.Lock()
		st.avReaders--
		st.avMu.Unlock()
		if msg := strings.TrimSpace(stderr.String()); msg != "" {
			log.Printf("[ff] %s transcoder ended: %s", st.id, firstLine(msg))
		} else {
			log.Printf("[ff] %s transcoder ended", st.id)
		}
	}()

	w.Header().Set("Content-Type", "video/x-matroska")
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(http.StatusOK)
	flusher, _ := w.(http.Flusher)

	// Stream ffmpeg's stdout straight through, starting from its very first
	// byte so the Matroska header reaches this reader intact.
	buf := make([]byte, 32*1024)
	for {
		n, rerr := stdout.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				return
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if rerr != nil {
			return
		}
	}
}

// ── PTT speak relay (Flutter -> ESP32) ───────────────────────────────────────

func speakHandler(w http.ResponseWriter, r *http.Request) {
	streamID := pathID(r.URL.Path, "/speak/")
	if streamID == "" {
		http.Error(w, "missing stream_id", http.StatusBadRequest)
		return
	}
	if r.URL.Query().Get("token") != relayToken {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	if websocket.IsWebSocketUpgrade(r) {
		wsConn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("[speak-ws] upgrade error for %s: %v", streamID, err)
			return
		}
		defer wsConn.Close()
		log.Printf("[speak-ws] talkback session active: %s", streamID)

		streamsMu.Lock()
		st, ok := streams[streamID]
		streamsMu.Unlock()
		if !ok {
			return
		}

		const maxChunk = 3500
		msg := make([]byte, 0, 1+maxChunk)
		for {
			_, pcm, err := wsConn.ReadMessage()
			if err != nil {
				log.Printf("[speak-ws] talkback closed for %s", streamID)
				return
			}
			if len(pcm) == 0 {
				continue
			}

			st.mu.Lock()
			conn := st.wsConn
			if conn == nil {
				st.mu.Unlock()
				continue
			}

			for off := 0; off < len(pcm); off += maxChunk {
				end := off + maxChunk
				if end > len(pcm) {
				end = len(pcm)
				}
				msg = append(msg[:0], frameTypeSpeak)
				msg = append(msg, pcm[off:end]...)
				if err := conn.WriteMessage(websocket.BinaryMessage, msg); err != nil {
					log.Printf("[speak-ws] write to %s failed: %v", streamID, err)
					st.mu.Unlock()
					return
				}
			}
			st.mu.Unlock()
		}
	}

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	pcm, err := io.ReadAll(io.LimitReader(r.Body, 64*1024))
	r.Body.Close()
	if err != nil || len(pcm) == 0 {
		http.Error(w, "bad request body", http.StatusBadRequest)
		return
	}

	streamsMu.Lock()
	st, ok := streams[streamID]
	streamsMu.Unlock()
	if !ok {
		http.Error(w, "stream not found", http.StatusNotFound)
		return
	}

	st.mu.Lock()
	defer st.mu.Unlock()
	conn := st.wsConn
	if conn == nil {
		http.Error(w, "device not connected", http.StatusServiceUnavailable)
		return
	}

	// The ESP32's WS receive buffer is 4096 B; keep chunks under that so a
	// PTT burst arrives without fragmentation.
	const maxChunk = 3500
	msg := make([]byte, 0, 1+maxChunk)
	for off := 0; off < len(pcm); off += maxChunk {
		end := off + maxChunk
		if end > len(pcm) {
			end = len(pcm)
		}
		msg = append(msg[:0], frameTypeSpeak)
		msg = append(msg, pcm[off:end]...)
		if err := conn.WriteMessage(websocket.BinaryMessage, msg); err != nil {
			log.Printf("[speak] write to %s failed: %v", streamID, err)
			http.Error(w, "relay failed", http.StatusServiceUnavailable)
			return
		}
	}
	w.WriteHeader(http.StatusOK)
}

// ── Health ───────────────────────────────────────────────────────────────────

func healthHandler(w http.ResponseWriter, r *http.Request) {
	type entry struct {
		Connected bool `json:"connected"`
		HaveFrame bool `json:"have_frame"`
		AVReaders int  `json:"av_readers"`
	}
	out := map[string]entry{}

	streamsMu.Lock()
	ids := make([]*streamState, 0, len(streams))
	for _, st := range streams {
		ids = append(ids, st)
	}
	streamsMu.Unlock()

	for _, st := range ids {
		st.mu.Lock()
		connected, have := st.connected, st.haveFrame
		st.mu.Unlock()
		st.avMu.Lock()
		readers := st.avReaders
		st.avMu.Unlock()
		out[st.id] = entry{Connected: connected, HaveFrame: have, AVReaders: readers}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"status":  "ok",
		"streams": out,
	})
}

// ── main ─────────────────────────────────────────────────────────────────────

func pathID(path, prefix string) string {
	return strings.Trim(strings.TrimPrefix(path, prefix), "/")
}

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds)
	log.Printf("babytrack-relay starting (token %.4s..., go2rtc %s)", relayToken, go2rtcURL)

	wsMux := http.NewServeMux()
	wsMux.HandleFunc("/ingest/", ingestHandler)
	wsMux.HandleFunc("/health", healthHandler)

	mediaMux := http.NewServeMux()
	mediaMux.HandleFunc("/mjpeg/", mjpegHandler)
	mediaMux.HandleFunc("/audio/", audioHandler)
	mediaMux.HandleFunc("/av/", avHandler)
	mediaMux.HandleFunc("/speak/", speakHandler)
	mediaMux.HandleFunc("/health", healthHandler)

	errs := make(chan error, 2)
	go func() {
		log.Printf("WS ingest listening on %s:%s", bindAddr, wsPort)
		errs <- http.ListenAndServe(bindAddr+":"+wsPort, wsMux)
	}()
	go func() {
		log.Printf("media HTTP listening on %s:%s", bindAddr, httpPort)
		errs <- http.ListenAndServe(bindAddr+":"+httpPort, mediaMux)
	}()

	log.Fatalf("fatal: %v", <-errs)
}
