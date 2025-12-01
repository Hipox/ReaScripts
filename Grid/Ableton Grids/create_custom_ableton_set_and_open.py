# @noindex
# helper script for Ableton Grids (not a standalone ReaScript)

import gzip
import xml.etree.ElementTree as ET
from pathlib import Path
import subprocess
import sys
import os
# import soundfile as sf

# def check_dependencies():
#     missing = []
#     try:
#         import soundfile # pip install soundfile
#     except ImportError:
#         missing.append("soundfile")
#     return missing

# Folder where this script lives
BASE_DIR = Path(__file__).resolve().parent

als_dir_name = "Reaper_Warp_Template_modified Project"
default_als_name = "Reaper_Warp_Template"
out_als = BASE_DIR / als_dir_name / (f"{default_als_name}_modified.als")

start_bar = 5          # bar where the clip should start (1 = bar 1)
beats_per_bar = 4      # assuming 4/4; change if needed


def get_audio_tracks_and_clips(root: ET.Element):
    """
    Return a list of (AudioTrack, AudioClip) pairs, one per AudioTrack, in order.
    Track 1 -> pairs[0], Track 2 -> pairs[1], etc.
    """
    tracks = root.find(".//Tracks")
    if tracks is None:
        raise RuntimeError("No <Tracks> element found in ALS.")

    audio_tracks = tracks.findall("AudioTrack")
    if not audio_tracks:
        raise RuntimeError("No <AudioTrack> found in <Tracks>.")

    pairs = []
    for idx, track in enumerate(audio_tracks):
        clip = track.find(".//AudioClip")
        if clip is None:
            raise RuntimeError(
                f"No <AudioClip> found on AudioTrack index {idx} "
                "(0-based). Make sure your template ALS has a dummy clip "
                "on each audio track you want to use."
            )
        pairs.append((track, clip))

    return pairs


def get_project_tempo(root: ET.Element) -> float:
    tempo_elem = root.find(".//Tempo/Manual")
    if tempo_elem is None or "Value" not in tempo_elem.attrib:
        raise RuntimeError("Could not find project tempo in ALS.")
    return float(tempo_elem.get("Value"))


def return_als_name(paths_cnt: int) -> str:
    return f"{default_als_name}_{paths_cnt}.als"

def launch_als(out_als: Path, ableton_path: str) -> None:
    """
    Launch the generated ALS project in Ableton Live.

    Logic:
      1) Print ALS path to stdout (Lua side expects this).
      2) If ableton_path is non-empty and valid:
           - On macOS .app: use `open -a <app> <als>`
           - Otherwise: call [exe, als]
         If that fails or is invalid, print a warning and fall back.
      3) Fallback to system association:
           - Windows: os.startfile(als)
           - macOS:   open als
           - Linux:   xdg-open als
    """
    # Always print the ALS path for the caller (REAPER Lua)
    print(out_als)

    als_str = str(out_als)
    exe = (ableton_path or "").strip()

    # --- 1) Try user-provided Ableton executable / app ---
    if exe:
        is_valid_exe = os.path.isfile(exe)
        is_valid_app = (sys.platform == "darwin" and exe.endswith(".app") and os.path.isdir(exe))

        if is_valid_exe or is_valid_app:
            try:
                if sys.platform == "darwin" and exe.endswith(".app"):
                    # Launch specific .app with ALS as argument
                    subprocess.Popen(["open", "-a", exe, als_str])
                else:
                    # Generic: run the executable with ALS path
                    subprocess.Popen([exe, als_str])
                return
            except Exception as e:
                print(
                    f"[WARN] Failed to launch Ableton via provided path: {exe} ({e})",
                    file=sys.stderr,
                )
        else:
            print(
                f"[WARN] Provided Ableton path is not valid: {exe}",
                file=sys.stderr,
            )

    # --- 2) Fallback: system default for .als ---
    try:
        if sys.platform.startswith("win"):
            # Default associated app (usually Ableton Live)
            os.startfile(als_str)  # type: ignore[attr-defined]
        elif sys.platform == "darwin":
            subprocess.Popen(["open", als_str])
        else:
            subprocess.Popen(["xdg-open", als_str])
    except Exception as e:
        print(f"[ERROR] Failed to launch ALS via system association: {e}", file=sys.stderr)


def main():

    # --- ARGUMENTS FROM REAPER/LUA ---
    # We expect:
    #   argv[1] = Ableton executable / app path (can be "" if not used)
    #   argv[2+] = audio file paths
    #
    # We also ignore any flags like --check-deps just in case.
    raw_args = sys.argv[1:]

    ableton_path = ""
    paths = []

    if raw_args:
        ableton_path = raw_args[0] or ""
        paths = raw_args[1:]

    # Fallback (for testing from terminal if no audio paths given)
    if not paths:
        paths = [
            r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton beatgrids\Media\Earth, Wind & Fire - September.flac",
            r"D:\WORKDIR\MUSIC\Reaper Default Save Path\test ableton bea...ia\Rvssian, Lil Baby, Byron Messia - Choppa (Original Mix).flac"
        ]

    # pick a template ALS depending on number of paths
    als_path = BASE_DIR / als_dir_name / return_als_name(len(paths))

    if not als_path.exists():
        raise FileNotFoundError(f"ALS not found: {als_path}")

    # --- 1) Read and parse ALS ---
    with gzip.open(als_path, "rb") as f:
        xml_bytes = f.read()

    root = ET.fromstring(xml_bytes.decode("utf-8"))

    # --- 2) Get tracks+clips + tempo ---
    track_clip_pairs = get_audio_tracks_and_clips(root)  # (AudioTrack, AudioClip) per track
    # tempo = get_project_tempo(root)

    if len(track_clip_pairs) < len(paths):
        raise RuntimeError(
            f"Template has only {len(track_clip_pairs)} audio tracks with clips, "
            f"but you passed {len(paths)} paths.\n"
            f"Add more dummy tracks/clips to your template ALS or pass fewer files."
        )

    # --- 3) For each path, update corresponding track's clip + track name ---
    for idx, p in enumerate(paths):
        track, clip = track_clip_pairs[idx]  # Track idx+1
        audio_file = Path(p)

        # 3a) Read audio file info
        if not audio_file.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_file}")

        # info = sf.info(str(audio_file))
        frames = 200000000 # info.frames # high value to accomodate any length of an audio
        # sr = info.samplerate
        # duration_sec = frames / sr

        # duration in beats at the project tempo
        beats_len = 50000 #duration_sec * tempo / 60.0 # high value to accomodate any length of an audio

        # clip start in beats from song start
        start_beats = (start_bar - 1) * beats_per_bar
        end_beats = start_beats + beats_len

        # # --- 4) Point clip to our audio file (more aggressive) ---
        file_ref = clip.find(".//SampleRef/FileRef")
        if file_ref is None:
            raise RuntimeError(
                "AudioClip has no <SampleRef>/<FileRef> – ALS structure differs?"
            )

        # Normalize absolute path to forward slashes (Ableton convention)
        abs_path = audio_file.resolve().as_posix()

        # 4a) RelativePathType -> absolute
        rel_type = file_ref.find("RelativePathType")
        if rel_type is not None:
            # 1 usually means "absolute path"
            rel_type.set("Value", "1")

        # 4b) Set ALL Path elements under this FileRef
        for path_elem in file_ref.findall(".//Path"):
            path_elem.set("Value", abs_path)

        # 4c) Set ALL FileName elements under this FileRef
        for name_elem in file_ref.findall(".//FileName"):
            name_elem.set("Value", audio_file.name)

        # 4d) Set ALL RelativePath elements (heavy-handed but safe here)
        for rel_elem in file_ref.findall(".//RelativePath"):
            rel_elem.set("Value", abs_path)

        # --- 4e) Update sample metadata under <SampleRef> ---
        sample_ref = clip.find(".//SampleRef")
        if sample_ref is not None:
            default_duration_elem = sample_ref.find("DefaultDuration")
            if default_duration_elem is not None:
                default_duration_elem.set("Value", str(frames))

            # default_sr_elem = sample_ref.find("DefaultSampleRate")
            # if default_sr_elem is not None:
            #     default_sr_elem.set("Value", str(sr))

        # --- 4f) Set clip name to file name (without extension) ---
        clip_name = audio_file.stem

        # Clip naming
        name_elem = clip.find("Name")
        if name_elem is not None:
            if "Value" in name_elem.attrib:
                name_elem.set("Value", clip_name)

            # Some ALS variants use <Name><UserName Value="..."/></Name>
            user_name_elem = name_elem.find("UserName")
            if user_name_elem is not None and "Value" in user_name_elem.attrib:
                user_name_elem.set("Value", clip_name)
        else:
            # Fallback: look directly for a UserName child
            user_name_elem = clip.find("UserName")
            if user_name_elem is not None and "Value" in user_name_elem.attrib:
                user_name_elem.set("Value", clip_name)

        # --- 4g) Rename track to match clip/file name ---
        track_name = clip_name

        track_name_elem = track.find("Name")
        if track_name_elem is not None:
            # direct attribute on <Name>
            if "Value" in track_name_elem.attrib:
                track_name_elem.set("Value", track_name)

            eff_name_elem = track_name_elem.find("EffectiveName")
            if eff_name_elem is not None and "Value" in eff_name_elem.attrib:
                eff_name_elem.set("Value", track_name)

            track_user_name_elem = track_name_elem.find("UserName")
            if track_user_name_elem is not None and "Value" in track_user_name_elem.attrib:
                track_user_name_elem.set("Value", track_name)
        else:
            # Fallback: <UserName> directly under <AudioTrack>
            track_user_name_elem = track.find("UserName")
            if track_user_name_elem is not None and "Value" in track_user_name_elem.attrib:
                track_user_name_elem.set("Value", track_name)

        # --- 5) Set clip timing + disable loop ---
        clip.set("Time", str(start_beats))

        current_start_elem = clip.find("CurrentStart")
        if current_start_elem is not None:
            current_start_elem.set("Value", str(start_beats))

        current_end_elem = clip.find("CurrentEnd")
        if current_end_elem is not None:
            current_end_elem.set("Value", str(end_beats))

        loop_elem = clip.find("Loop")
        if loop_elem is not None:
            # Turn looping OFF
            loop_on = loop_elem.find("LoopOn")
            if loop_on is not None:
                loop_on.set("Value", "false")

            loop_start = loop_elem.find("LoopStart")
            if loop_start is not None:
                loop_start.set("Value", "0")

            loop_end = loop_elem.find("LoopEnd")
            if loop_end is not None:
                loop_end.set("Value", str(beats_len))

            out_marker = loop_elem.find("OutMarker")
            if out_marker is not None:
                out_marker.set("Value", str(beats_len))

            hidden_loop_start = loop_elem.find("HiddenLoopStart")
            if hidden_loop_start is not None:
                hidden_loop_start.set("Value", "0")

            hidden_loop_end = loop_elem.find("HiddenLoopEnd")
            if hidden_loop_end is not None:
                hidden_loop_end.set("Value", str(beats_len))

    # --- 6) Write back as ALS (after all paths have been processed) ---
    new_xml_bytes = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    with gzip.open(out_als, "wb") as f:
        f.write(new_xml_bytes)

    if out_als.exists():
        launch_als(out_als, ableton_path)
    else:
        print("")

if __name__ == "__main__":
    main()
