# @noindex
# helper script for Ableton Grids (not a standalone ReaScript)

import gzip
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import statistics

def check_dependencies():
    return []


# ------------ CONFIG ------------

BASE_DIR = Path(__file__).resolve().parent
als_dir_name = "Reaper_Warp_Template_modified Project"
default_als_name = "Reaper_Warp_Template"

out_als = BASE_DIR / als_dir_name / (f"{default_als_name}_modified.als")
out_path = BASE_DIR / "ableton_result.json"


# ------------ HELPERS ------------

def load_als_root(path):
    with gzip.open(path, "rb") as f:
        xml_bytes = f.read()
    return ET.fromstring(xml_bytes.decode("utf-8"))


def find_clip_for_audio(root, audio_path):
    target_abs = audio_path.resolve().as_posix()
    target_name = audio_path.name

    for clip in root.findall(".//AudioClip"):
        file_ref = clip.find(".//SampleRef/FileRef")
        if file_ref is None:
            continue

        path_vals = [p.get("Value") for p in file_ref.findall(".//Path") if p.get("Value")]
        fname_vals = [n.get("Value") for n in file_ref.findall(".//FileName") if n.get("Value")]

        match = False

        for p in path_vals:
            p_norm = p.replace("\\", "/")
            if p_norm == target_abs:
                match = True
                break
            if Path(p_norm).name == target_name:
                match = True
                break

        if not match and target_name in fname_vals:
            match = True

        if match:
            return clip

    return None


def extract_warp_markers(clip):
    wm_container = clip.find("WarpMarkers")
    if wm_container is None:
        return [], []

    markers = []
    for wm in wm_container.findall("WarpMarker"):
        try:
            sec = float(wm.get("SecTime", "0"))
            beat = float(wm.get("BeatTime", "0"))
        except:
            continue
        markers.append((beat, sec))

    markers.sort(key=lambda m: m[0])

    beats = [b for (b, s) in markers]
    times = [s for (b, s) in markers]
    return times, beats


def compute_bpms_from_times_beats(times, beats):
    n = min(len(times), len(beats))
    if n < 2:
        return []

    bpms = []
    last_bpm = 0.0

    for i in range(n - 1):
        dt = times[i+1] - times[i]
        db = beats[i+1] - beats[i]
        if dt <= 0 or db == 0:
            bpm = last_bpm if last_bpm > 0 else 0.0
        else:
            bpm = 60.0 * db / dt

        bpms.append(bpm)
        last_bpm = bpm

    bpms.append(last_bpm)
    return bpms


def round_if_close(bpm, tol=0.0001):
    if bpm <= 0:
        return bpm
    nearest = round(bpm)
    if abs(bpm - nearest) < tol:
        return float(nearest)
    return bpm


def pick_base_bpm(bpms):
    for b in bpms:
        if b > 0:
            return round_if_close(b)
    return 0.0


def estimate_straight_bpm_from_bpms(
    bpms,
    std_threshold=0.5,
    range_threshold=3.0,
    min_nonzero=4,
):
    vals = [b for b in bpms if b > 0]
    if len(vals) < min_nonzero:
        return None

    mean_bpm = statistics.mean(vals)
    stdev_bpm = statistics.pstdev(vals)
    bpm_range = max(vals) - min(vals)

    if stdev_bpm > std_threshold or bpm_range > range_threshold:
        return None

    snapped = round_if_close(mean_bpm, 0.1)
    return snapped


def get_clip_length_seconds_from_als(clip):
    lengths = []

    for sample_ref in clip.findall(".//SampleRef"):
        dur_node = sample_ref.find("DefaultDuration")
        sr_node = sample_ref.find("DefaultSampleRate")
        if dur_node is not None and sr_node is not None:
            try:
                dur = float(dur_node.get("Value", "0"))
                sr = float(sr_node.get("Value", "0"))
                if dur > 0 and sr > 0:
                    lengths.append(dur / sr)
            except:
                pass

        sl_node = sample_ref.find("SampleLength")
        sr2_node = sample_ref.find("SampleRate")
        if sl_node is not None and sr2_node is not None:
            try:
                sl = float(sl_node.get("Value", "0"))
                sr2 = float(sr2_node.get("Value", "0"))
                if sl > 0 and sr2 > 0:
                    lengths.append(sl / sr2)
            except:
                pass

    if lengths:
        return max(lengths)

    start_node = clip.find(".//CurrentStart")
    end_node = clip.find(".//CurrentEnd")
    if start_node is not None and end_node is not None:
        try:
            cs = float(start_node.get("Value", "0"))
            ce = float(end_node.get("Value", "0"))
            if ce > cs:
                return ce - cs
        except:
            pass

    return 0.0


def generate_bar_grid_from_length(base_bpm, item_len_sec, start_time=0.0, start_beat=0.0, beats_per_bar=4.0):
    if base_bpm <= 0 or item_len_sec <= 0:
        return [], [], []

    sec_per_quarter = 60.0 / base_bpm
    sec_per_bar = beats_per_bar * sec_per_quarter

    new_times = [start_time]
    new_beats = [start_beat]

    n = 1
    while True:
        t = start_time + n * sec_per_bar
        if t > item_len_sec:
            break
        b = start_beat + n * beats_per_bar
        new_times.append(t)
        new_beats.append(b)
        n += 1

    new_bpms = [base_bpm] * len(new_beats)
    return new_times, new_beats, new_bpms


# ------------ MAIN ------------

def main():
    if "--check-deps" in sys.argv:
        missing = check_dependencies()
        print("OK" if not missing else "MISSING:" + ",".join(missing))
        return

    paths = [arg for arg in sys.argv[1:] if not arg.startswith("--")]

    if not paths:
        paths = [
            r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton beatgrids\Media\Earth, Wind & Fire - September.flac",
            r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton beatgrids\test ableton beatgrids_2\Media\Rvssian, Lil Baby, Byron Messia - Choppa (Original Mix).flac"
        ]

    if not out_als.exists():
        raise FileNotFoundError(f"ALS not found: {out_als}")

    root = load_als_root(out_als)

    output = {
        "paths_list": list(paths),
        "times_list": [],
        "beats_list": [],
        "bpms_list": [],
        "straight_bpm_list": [],   # ONLY output
    }

    for idx, p in enumerate(paths):
        audio_file = Path(p)

        clip = find_clip_for_audio(root, audio_file)
        if clip is None:
            output["paths_list"][idx] = ""
            output["times_list"].append([])
            output["beats_list"].append([])
            output["bpms_list"].append([])
            output["straight_bpm_list"].append(0.0)
            continue

        times, beats = extract_warp_markers(clip)
        bpms = compute_bpms_from_times_beats(times, beats)

        # Ableton straight mode detection
        is_ableton_straight = False
        if beats:
            is_ableton_straight = max(beats) <= 1.0001

        straight_bpm = 0.0

        if is_ableton_straight:
            base_bpm = pick_base_bpm(bpms)
            straight_bpm = round(base_bpm, 3)

            item_len_sec = get_clip_length_seconds_from_als(clip)
            start_time = times[0] if times else 0.0
            start_beat = beats[0] if beats else 0.0

            if base_bpm > 0 and item_len_sec > 0:
                times, beats, bpms = generate_bar_grid_from_length(
                    base_bpm,
                    item_len_sec,
                    start_time,
                    start_beat,
                )
        else:
            detected = estimate_straight_bpm_from_bpms(bpms)
            if detected is not None:
                straight_bpm = detected

        # Always record straight_bpm_list (0.0 if not straight)
        output["paths_list"][idx] = str(audio_file)
        output["times_list"].append(times)
        output["beats_list"].append(beats)
        output["bpms_list"].append(bpms)
        output["straight_bpm_list"].append(straight_bpm)

    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(output, fh)

    if any(len(t) > 0 for t in output["times_list"]):
        print(str(out_path))
    else:
        print("failed")


if __name__ == "__main__":
    main()
