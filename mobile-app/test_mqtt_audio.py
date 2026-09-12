import paho.mqtt.client as mqtt
import base64
import wave
import sys
import threading
import time

# --- Configuration ---
BROKER = "broker.hivemq.com"
PORT = 1883
TOPIC = "cradle/+/speak" # Listens to all devices

# Audio specs from ESP32 / Flutter App
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2 # 16-bit = 2 bytes

# --- Setup ---
buffer = bytearray()
is_recording = False

print("Select mode:")
print("1: Live Playback (requires 'pip install pyaudio')")
print("2: Save to .wav file (Built-in, no extra dependencies)")
mode = input("Enter 1 or 2: ").strip()

if mode == '1':
    try:
        import pyaudio
        p = pyaudio.PyAudio()
        stream = p.open(format=pyaudio.paInt16,
                        channels=CHANNELS,
                        rate=SAMPLE_RATE,
                        output=True)
        print("Live playback initialized.")
    except ImportError:
        print("Error: PyAudio is not installed. Please run 'pip install pyaudio' or use mode 2.")
        sys.exit(1)
else:
    print("Saving to 'received_audio.wav'. Press Ctrl+C to stop and save the file.")

def on_connect(client, userdata, flags, rc):
    print(f"Connected to {BROKER} with result code {rc}")
    client.subscribe(TOPIC)
    print(f"Subscribed to topic: {TOPIC}")

def on_message(client, userdata, msg):
    global buffer, is_recording
    try:
        # Flutter app sends Base64 encoded PCM data
        pcm_data = base64.b64decode(msg.payload)
        
        if mode == '1':
            stream.write(pcm_data)
            print(f"Played {len(pcm_data)} bytes of audio data")
        else:
            buffer.extend(pcm_data)
            print(f"Recorded {len(pcm_data)} bytes (Total: {len(buffer)} bytes)")
            
    except Exception as e:
        print(f"Error processing message: {e}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

try:
    print(f"Connecting to {BROKER}...")
    client.connect(BROKER, PORT, 60)
    client.loop_forever()
except KeyboardInterrupt:
    print("\nStopping...")
finally:
    if mode == '1':
        stream.stop_stream()
        stream.close()
        p.terminate()
    elif mode == '2' and len(buffer) > 0:
        filename = "received_audio.wav"
        print(f"Saving {len(buffer)} bytes to {filename}...")
        with wave.open(filename, 'wb') as wf:
            wf.setnchannels(CHANNELS)
            wf.setsampwidth(SAMPLE_WIDTH)
            wf.setframerate(SAMPLE_RATE)
            wf.writeframes(buffer)
        print("Saved successfully. You can now play this file with any media player.")
