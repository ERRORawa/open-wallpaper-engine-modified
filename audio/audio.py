import numpy as np
from pysysaudio import SystemAudioRecorder
import socket
import struct
import subprocess
import time
import threading

CHUNK = 4096
SAMPLE_RATE = 44100
UDP_IP = "127.0.0.1"
UDP_PORT = 1324
LEFT_OUT = 64
RIGHT_OUT = 64
TOTAL_SIZE = 128
SILENCE_THRESHOLD = 0.005
DB_MIN = -60.0
REF_MAX_MAGNITUDE = CHUNK / 2.0
SMOOTHING_ALPHA = 0.2
VOLUME_REFRESH_INTERVAL = 0.5

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
recorder = SystemAudioRecorder(
    sample_rate=SAMPLE_RATE,
    channels=2,
    format="numpy",
    dtype="float32"
)
recorder.start_recording()

smooth_left = np.zeros(LEFT_OUT)
smooth_right = np.zeros(RIGHT_OUT)

current_volume = 0
volume_lock = threading.Lock()

def get_system_volume():
    try:
        cmd = "osascript -e 'output volume of (get volume settings)'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=1)
        volume = int(result.stdout.strip()) / 100.0
        return volume * 6
    except Exception:
        return current_volume

def update_volume_loop():
    global current_volume
    while True:
        new_vol = get_system_volume()
        with volume_lock:
            current_volume = new_vol
        time.sleep(VOLUME_REFRESH_INTERVAL)

volume_thread = threading.Thread(target=update_volume_loop, daemon=True)
volume_thread.start()

def a_weighting_curve(freqs):
    f = np.maximum(freqs, 1e-6)
    f2 = f ** 2
    ra = (12200 ** 2 * f2 ** 2) / (
        (f2 + 20.6 ** 2) *
        np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) *
        (f2 + 12200 ** 2)
    )
    f1k = 1000.0
    f1k2 = f1k ** 2
    ra_1k = (12200 ** 2 * f1k2 ** 2) / (
        (f1k2 + 20.6 ** 2) *
        np.sqrt((f1k2 + 107.7 ** 2) * (f1k2 + 737.9 ** 2)) *
        (f1k2 + 12200 ** 2)
    )
    coeff = ra / ra_1k
    coeff[freqs == 0] = 0.0
    return coeff

def process_channel(sig, smooth_state):
    n = len(sig)
    window = np.hanning(n)
    sig_windowed = sig * window

    fft_data = np.abs(np.fft.rfft(sig_windowed))
    max_val = np.max(fft_data)

    if max_val < SILENCE_THRESHOLD:
        raw_vals = np.zeros(LEFT_OUT)
    else:
        linear_freqs = np.fft.rfftfreq(n, d=1/SAMPLE_RATE)
        a_weight = a_weighting_curve(linear_freqs)
        weighted_mag = fft_data * a_weight
        eps = 1e-12
        db = 20 * np.log10(weighted_mag + eps) - 20 * np.log10(REF_MAX_MAGNITUDE)
        db = np.clip(db, DB_MIN, 0.0)
        raw_vals = (db - DB_MIN) / (-DB_MIN)
        f_min = 20.0
        f_max = SAMPLE_RATE / 2.0
        log_freqs = np.logspace(np.log10(f_min), np.log10(f_max), LEFT_OUT)
        raw_vals = np.interp(log_freqs, linear_freqs, raw_vals)
        raw_vals = np.nan_to_num(raw_vals, nan=0.0)
        raw_vals = np.clip(raw_vals, 0.0, 1.0)

    smoothed = SMOOTHING_ALPHA * raw_vals + (1 - SMOOTHING_ALPHA) * smooth_state
    smooth_state[:] = smoothed
    return smoothed

try:
    while True:
        audio_block = next(recorder.stream())
        target_block = audio_block[:CHUNK]
        samples = target_block.flatten()

        left = samples[0::2][:CHUNK]
        right = samples[1::2][:CHUNK]

        left_out = process_channel(left, smooth_left)
        right_out = process_channel(right, smooth_right)

        output = np.concatenate([left_out, right_out])

        with volume_lock:
            vol = current_volume
        output = output * vol
        output = np.clip(output, 0.0, 1.0)

        packet = struct.pack(f'<{TOTAL_SIZE}f', *output)
        sock.sendto(packet, (UDP_IP, UDP_PORT))

finally:
    recorder.stop_recording()
    sock.close()
