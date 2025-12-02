# @author Hipox
# @description Ableton Extract Grid
# @noindex
# NoIndex: true
# @about helper script for Ableton Grids (not a standalone ReaScript)

import gzip
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import statistics


def check_dependencies():
    """ReaPack helper: this script has no external Python deps."""
    return []


# ------------ CONFIG ------------

BASE_DIR = Path(__file__).resolve().parent
als_dir_name = "Reaper_Warp_Template_modified Project"
default_als_name = "Reaper_Warp_Template"

# This is the ALS that Reaper / the Lua script keeps re-saving
out_als = BASE_DIR / als_dir_name / f"{default_als_name}_modified.als"

# Where we write the JSON that the Lua script reads
out_path = BASE_DIR / "ableton_result.json"


# ------------ XML / ALS HELPERS ------------

def load_als_root(path: Path) -> ET.Element:
    """Load a .als (gzipped XML) and return the XML root element."""
    with gzip.open(path, "rb") as f:
        xml_bytes = f.read()
    return ET.fromstring(xml_bytes.decode("utf-8"))


def find_clip_for_audio(root: ET.Element, audio_path: Path):
    """
    Try to locate the <AudioClip> in the ALS that refers to `audio_path`.

    Matching strategy:
      * First try to match full path (normalized to /).
      * Then fall back to just the file name.
    """
    target_abs = audio_path.resolve().as_posix()
    target_name = audio_path.name

    for clip in root.findall(".//AudioClip"):
        file_ref = clip.find(".//SampleRef/FileRef")
        if file_ref is None:
            continue

        path_vals = [
            p.get("Value") for p in file_ref.findall(".//Path") if p.get("Value")
        ]
        fname_vals = [
            n.get("Value") for n in file_ref.findall(".//FileName") if n.get("Value")
        ]

        match = False

        # Match by path
        for p in path_vals:
            p_norm = p.replace("\\", "/")
            if p_norm == target_abs:
                match = True
                break
            # fall back to comparing just the file name
            if Path(p_norm).name == target_name:
                match = True
                break

        # Match by FileName only
        if not match and target_name in fname_vals:
            match = True

        if match:
            return clip

    return None


def extract_warp_markers(clip):
    """Return (times, beats) from <WarpMarkers> in the clip."""
    wm_container = clip.find("WarpMarkers")
    if wm_container is None:
        return [], []

    markers = []
    for wm in wm_container.findall("WarpMarker"):
        try:
            sec = float(wm.get("SecTime", "0"))
            beat = float(wm.get("BeatTime", "0"))
        except Exception:
            continue
        markers.append((beat, sec))

    markers.sort(key=lambda m: m[0])

    beats = [b for (b, s) in markers]
    times = [s for (b, s) in markers]
    return times, beats


# ------------ BPM / GRID HELPERS ------------

def compute_bpms_from_times_beats(times, beats):
    """Compute per-segment instantaneous BPMs from warp markers."""
    n = min(len(times), len(beats))
    if n < 2:
        return []

    bpms = []
    last_bpm = 0.0

    for i in range(n - 1):
        dt = times[i + 1] - times[i]
        db = beats[i + 1] - beats[i]
        if dt <= 0 or db == 0:
            bpm = last_bpm if last_bpm > 0 else 0.0
        else:
            bpm = 60.0 * db / dt

        bpms.append(bpm)
        last_bpm = bpm

    bpms.append(last_bpm)
    return bpms


def round_if_close(bpm, tol=1e-4):
    """If bpm is very close to an integer, snap it."""
    if bpm <= 0:
        return bpm
    nearest = round(bpm)
    if abs(bpm - nearest) < tol:
        return float(nearest)
    return bpm


def pick_base_bpm(bpms):
    """Pick a reasonable base BPM from a list (first non-zero, snapped)."""
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
    """
    Heuristic: detect if a variable grid is "straight-ish" enough to be
    approximated by a single BPM.
    """
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
    """
    Try to estimate the audio length in seconds for this clip.

    We look at:
      * SampleRef/DefaultDuration & DefaultSampleRate
      * SampleRef/SampleLength & SampleRate
      * As a last resort, CurrentStart / CurrentEnd on the clip.
    """
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
            except Exception:
                pass

        sl_node = sample_ref.find("SampleLength")
        sr2_node = sample_ref.find("SampleRate")
        if sl_node is not None and sr2_node is not None:
            try:
                sl = float(sl_node.get("Value", "0"))
                sr2 = float(sr2_node.get("Value", "0"))
                if sl > 0 and sr2 > 0:
                    lengths.append(sl / sr2)
            except Exception:
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
        except Exception:
            pass

    return 0.0


def generate_bar_grid_from_length(
    base_bpm: float,
    item_len_sec: float,
    start_time: float = 0.0,
    start_beat: float = 0.0,
    beats_per_bar_quarter: float = 4.0,
):
    """
    Generate a straight bar grid for a given BPM and time signature.

    beats_per_bar_quarter:
        Number of quarter-note beats per bar.
        * 4/4 -> 4
        * 3/4 -> 3
        * 6/8 -> 3  (six eighths = three quarters)
        * 12/8 -> 4 (twelve eighths = four quarters)
    """
    if base_bpm <= 0 or item_len_sec <= 0:
        return [], [], []

    sec_per_quarter = 60.0 / base_bpm
    sec_per_bar = beats_per_bar_quarter * sec_per_quarter

    times = [start_time]
    beats = [start_beat]

    n = 1
    while True:
        t = start_time + n * sec_per_bar
        if t > item_len_sec:
            break
        b = start_beat + n * beats_per_bar_quarter
        times.append(t)
        beats.append(b)
        n += 1

    bpms = [base_bpm] * len(beats)
    return times, beats, bpms


# ------------ TIME SIGNATURE HELPERS ------------

def extract_time_signature_for_clip(clip, default_num=4, default_den=4):
    """
    Read the time-signature for this AudioClip from ALS XML.

    In your template ALS the structure is:

      AudioClip
        TimeSignature
          TimeSignatures
            RemoteableTimeSignature
              Numerator   (Value="3")
              Denominator (Value="4")

    If anything is missing/invalid, fall back to defaults.
    """
    ts = clip.find(".//TimeSignature/TimeSignatures/RemoteableTimeSignature")
    num = default_num
    den = default_den

    if ts is not None:
        num_node = ts.find("Numerator")
        den_node = ts.find("Denominator")

        if num_node is not None:
            v = num_node.get("Value")
            try:
                num = int(float(v))
            except (TypeError, ValueError):
                pass

        if den_node is not None:
            v = den_node.get("Value")
            try:
                den = int(float(v))
            except (TypeError, ValueError):
                pass

    if num <= 0:
        num = default_num
    if den <= 0:
        den = default_den

    return num, den


# ------------ MAIN ------------

def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    paths = [Path(p) for p in argv]

    if not paths:
        paths = [
            Path(r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton beatgrids\Media\Earth, Wind & Fire - September.flac"),
            Path(r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton beatgrids\test ableton beatgrids_2\Media\Rvssian, Lil Baby, Byron Messia - Choppa (Original Mix).flac"),
            Path(r"C:\Users\Peter\Downloads\test djay\Sing2Piano - Amazing Grace (Key of F) - Piano Karaoke Version.mp3"),
        ]


    # All CLI args are treated as audio file paths.
    # if not paths:
    #     # No files given – nothing to do.
    #     print("failed")
    #     return

    if not out_als.exists():
        raise FileNotFoundError(f"ALS not found: {out_als}")

    root = load_als_root(out_als)

    output = {
        "paths_list": [str(p) for p in paths],
        "times_list": [],
        "beats_list": [],
        "bpms_list": [],
        "straight_bpm_list": [],
        # NEW: per-song time signature and derived beats_per_bar in quarters
        "time_sig_num_list": [],
        "time_sig_den_list": [],
        "beats_per_bar_quarter_list": [],
    }

    for idx, audio_file in enumerate(paths):
        clip = find_clip_for_audio(root, audio_file)
        if clip is None:
            continue

        # --- Time signature ---
        ts_num, ts_den = extract_time_signature_for_clip(clip, default_num=4, default_den=4)
        if ts_den > 0:
            beats_per_bar_quarter = ts_num * (4.0 / ts_den)
        else:
            beats_per_bar_quarter = float(ts_num)

        # --- Warp markers / BPMs ---
        times, beats = extract_warp_markers(clip)
        bpms = compute_bpms_from_times_beats(times, beats)

        # Detect Ableton "Straight" warp mode:
        # In your template, straight clips keep BeatTime <= 1 bar in the ALS.
        is_ableton_straight = bool(beats) and max(beats) <= 1.0001

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
                    beats_per_bar_quarter=beats_per_bar_quarter,
                )
        else:
            detected = estimate_straight_bpm_from_bpms(bpms)
            if detected is not None:
                straight_bpm = detected

        # Fill JSON
        output["times_list"].append(times)
        output["beats_list"].append(beats)
        output["bpms_list"].append(bpms)
        output["straight_bpm_list"].append(straight_bpm)
        output["time_sig_num_list"].append(ts_num)
        output["time_sig_den_list"].append(ts_den)
        output["beats_per_bar_quarter_list"].append(beats_per_bar_quarter)

    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(output, fh)

    if any(len(t) > 0 for t in output["times_list"]):
        # Lua script expects the JSON path on stdout when success
        print(str(out_path))
    else:
        print("failed")


if __name__ == "__main__":
    main()
