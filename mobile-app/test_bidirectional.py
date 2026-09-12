import socket
import sys
import time
import threading
import struct

try:
    import pyaudio
except ImportError:
    print("\n[ERROR] 'pyaudio' library is not installed.")
    print("Please install it using: pip install pyaudio\n")
    sys.exit(1)

# Audio Parameters matching ESP32 firmware & Flutter app
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
CHUNK = 512  # 512 frames = 1024 bytes per packet (matches LiveSpeakService _chunkBytes)

ESP32_PORT = 8282

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_bidirectional.py <ESP32_IP>")
        print("Example: python test_bidirectional.py 192.168.0.112")
        sys.exit(1)

    esp32_ip = sys.argv[1]
    print(f"--- Starting Bi-Directional UDP Audio Test with ESP32 ({esp32_ip}) ---")

    # Initialize PyAudio
    p = pyaudio.PyAudio()

    # Open Speaker Stream (Output)
    speaker_stream = p.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=RATE,
        output=True,
        frames_per_buffer=CHUNK
    )

    # Open Mic Stream (Input)
    mic_stream = p.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=RATE,
        input=True,
        frames_per_buffer=CHUNK
    )

    # Setup UDP Socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0', 0)) # bind to ephemeral port
    sock.settimeout(2.0)

    running = True

    # 1. Thread: Listen to ESP32 Mic -> Play on Laptop Speaker
    def receive_and_play():
        nonlocal running
        print("[SPEAKER THREAD] Listening for audio from ESP32...")
        packets_received = 0
        while running:
            try:
                data, addr = sock.recvfrom(4096)
                if data:
                    packets_received += 1
                    speaker_stream.write(data)
                    
                    if packets_received % 50 == 0:
                        # Calculate audio energy (volume level)
                        count = len(data) // 2
                        shorts = struct.unpack(f"<{count}h", data)
                        avg_energy = sum(abs(s) for s in shorts) // count if count > 0 else 0
                        print(f"🔊 Received audio from ESP32 | Packets: {packets_received} | Volume Level: {avg_energy}")
            except socket.timeout:
                continue
            except Exception as e:
                if running:
                    print(f"[SPEAKER ERROR] {e}")
                break

    # 2. Thread: Record Laptop Mic -> Send to ESP32 Speaker
    def record_and_send():
        nonlocal running
        print("[MIC THREAD] Streaming laptop mic to ESP32 speaker...")
        packets_sent = 0
        GAIN = 8.0  # High gain boost for maximum clear volume on ESP32 speaker
        
        while running:
            try:
                raw_data = mic_stream.read(CHUNK, exception_on_overflow=False)
                if raw_data:
                    # Apply gain boost to PCM16 samples
                    count = len(raw_data) // 2
                    shorts = list(struct.unpack(f"<{count}h", raw_data))
                    boosted = [max(-32768, min(32767, int(s * GAIN))) for s in shorts]
                    boosted_data = struct.pack(f"<{count}h", *boosted)
                    
                    sock.sendto(boosted_data, (esp32_ip, ESP32_PORT))
                    packets_sent += 1
                    
                    if packets_sent % 50 == 0:
                        avg_energy = sum(abs(s) for s in boosted) // count if count > 0 else 0
                        print(f"🎤 Sent mic audio to ESP32 | Packets: {packets_sent} | Mic Volume: {avg_energy}")
            except Exception as e:
                if running:
                    print(f"[MIC ERROR] {e}")
                break

    # Start threads
    t_recv = threading.Thread(target=receive_and_play, daemon=True)
    t_send = threading.Thread(target=record_and_send, daemon=True)

    t_recv.start()
    t_send.start()

    # Send start command to ESP32 to start streaming mic data to laptop
    start_cmd = b'{"cmd":"start_recording"}'
    print(f"Sending start_recording command to {esp32_ip}:{ESP32_PORT}...")
    for _ in range(3):
        sock.sendto(start_cmd, (esp32_ip, ESP32_PORT))
        time.sleep(0.05)

    print("\n✅ LIVE TEST RUNNING! Press Ctrl+C to stop.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping audio test...")
    finally:
        running = False
        # Send stop command
        stop_cmd = b'{"cmd":"stop_recording"}'
        sock.sendto(stop_cmd, (esp32_ip, ESP32_PORT))
        time.sleep(0.1)

        # Cleanup
        speaker_stream.stop_stream()
        speaker_stream.close()
        mic_stream.stop_stream()
        mic_stream.close()
        p.terminate()
        sock.close()
        print("Test stopped successfully.")

if __name__ == "__main__":
    main()
