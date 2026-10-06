#!/usr/bin/env python3
"""Generates the reel's AI shots with Google's Veo through the Gemini API.

For every "ai" shot in shots.json without a clip in clips/, it sends the
shot's prompt plus the shared style, waits for the video and saves it as
clips/<ID>.mp4. Existing clips are kept, so a rerun only fills the gaps (and
costs nothing for shots already done). Standard library only.

    GEMINI_API_KEY=... python3 marketing/reel60/generate_clips.py [--shots S01,S04] [--model veo-...]

Without --model it picks the newest Veo model the key can use.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
API = "https://generativelanguage.googleapis.com/v1beta"
NEGATIVE = "text, captions, watermark, logo, readable phone screen, distorted hands, extra fingers, alcohol bottles"


def request(method, url, key, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "x-goog-api-key": key,
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {url.split('?')[0]} failed: {err.code} {err.read().decode(errors='replace')[:600]}")


def pick_model(key):
    models = request("GET", f"{API}/models?pageSize=1000", key).get("models", [])
    veo = sorted(
        m["name"].split("/", 1)[1] for m in models
        if "veo" in m["name"] and "predictLongRunning" in m.get("supportedGenerationMethods", [])
    )
    if not veo:
        sys.exit("This API key has no Veo model. Enable billing in Google AI Studio and try again.")
    print("Veo models available:", ", ".join(veo))
    # Prefer the newest full model over fast/preview variants.
    stable = [m for m in veo if "fast" not in m and "preview" not in m] or veo
    return stable[-1]


def download(uri, key, out):
    sep = "&" if "?" in uri else "?"
    req = urllib.request.Request(f"{uri}{sep}alt=media", headers={"x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=300) as resp:
        out.write_bytes(resp.read())


def generate(shot, style, model, key):
    body = {
        "instances": [{"prompt": f"{shot['prompt']} {style}"}],
        "parameters": {"aspectRatio": "9:16", "negativePrompt": NEGATIVE},
    }
    op = request("POST", f"{API}/models/{model}:predictLongRunning", key, body)
    name = op["name"]
    started = time.time()
    while not op.get("done"):
        if time.time() - started > 900:
            sys.exit(f"{shot['id']}: no video after 15 minutes")
        time.sleep(10)
        op = request("GET", f"{API}/{name}", key)
    if "error" in op:
        print(f"{shot['id']}: failed: {op['error'].get('message')}")
        return None
    samples = op.get("response", {}).get("generateVideoResponse", {}).get("generatedSamples", [])
    if not samples:
        reasons = op.get("response", {}).get("generateVideoResponse", {}).get("raiMediaFilteredReasons")
        print(f"{shot['id']}: no video returned{f' ({reasons})' if reasons else ''}")
        return None
    return samples[0]["video"]["uri"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", default="", help="comma-separated shot IDs (default: all missing)")
    parser.add_argument("--model", default="")
    parser.add_argument("--redo", action="store_true", help="regenerate even if a clip exists")
    args = parser.parse_args()

    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("Set GEMINI_API_KEY (Google AI Studio API key with billing enabled).")
    config = json.loads((HERE / "shots.json").read_text())
    wanted = {s.strip() for s in args.shots.split(",") if s.strip()}
    clips = HERE / "clips"
    clips.mkdir(exist_ok=True)
    todo = [
        s for s in config["shots"]
        if s["type"] == "ai" and (not wanted or s["id"] in wanted)
        and (args.redo or not (clips / f"{s['id']}.mp4").exists())
    ]
    if not todo:
        print("Nothing to generate.")
        return
    model = args.model or pick_model(key)
    print(f"Generating {len(todo)} clips with {model}")
    failed = []
    for shot in todo:
        print(f"{shot['id']}: generating…", flush=True)
        uri = generate(shot, config["style"], model, key)
        if uri:
            download(uri, key, clips / f"{shot['id']}.mp4")
            print(f"{shot['id']}: saved")
        else:
            failed.append(shot["id"])
    if failed:
        print("Not generated (rewrite the prompt or rerun):", ", ".join(failed))


if __name__ == "__main__":
    main()
