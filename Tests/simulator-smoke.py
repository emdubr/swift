#!/usr/bin/env python3
"""Bounded no-dependency CoreSimulator launch check for GitHub-hosted macOS.

A successful xcodebuild or a PID printed by simctl alone is NOT proof that
the native SwiftUI view reached the foreground. Run a minimal probe first,
then the production root. Persist diagnostics on *every* failure.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

BUNDLE = "com.fieldos.native"
ROOT = Path("build/screenshots")
ROOT.mkdir(parents=True, exist_ok=True)


def pid_from_output(output: str, bundle: str = BUNDLE) -> int | None:
    match = re.search(r"^" + re.escape(bundle) + r": (\d+)\s*$", output, re.MULTILINE)
    return int(match.group(1)) if match else None


def bounded(args: list[str], seconds: int = 15) -> tuple[int, str]:
    """Never let a simulator/host log command occupy the whole workflow."""
    try:
        result = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=seconds)
        return result.returncode, result.stdout[-200_000:]
    except subprocess.TimeoutExpired as error:
        data = error.stdout or b""
        if isinstance(data, bytes):
            data = data.decode("utf-8", errors="replace")
        return 124, data[-200_000:] + f"\nCOMMAND TIMED OUT after {seconds}s: {args}\n"
    except OSError as error:
        return 126, str(error)


def still_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def capture_crashes(device: str, label: str) -> None:
    ROOT.joinpath(label + "-host-log.txt").write_text(
        bounded(["log", "show", "--last", "3m", "--style", "compact",
                 "--predicate", 'process == "FIELD iOS" OR eventMessage CONTAINS[c] "com.fieldos.native"'],
                seconds=12)[1]
    )
    reports = [
        Path.home() / "Library/Developer/CoreSimulator/Devices" / device /
        "data/Library/Logs/DiagnosticReports",
        Path.home() / "Library/Logs/DiagnosticReports"
    ]
    for directory in reports:
        if not directory.is_dir():
            continue
        for crash in directory.iterdir():
            if not crash.is_file() or crash.suffix not in (".ips", ".crash"):
                continue
            if "FIELD" not in crash.name and "JetsamEvent" not in crash.name:
                continue
            try:
                if time.time() - crash.stat().st_mtime < 420 and crash.stat().st_size < 1_500_000:
                    shutil.copy2(crash, ROOT / (label + "-" + crash.name))
            except OSError:
                continue


def launch(device: str, label: str, args: list[str], bundle: str = BUNDLE) -> bool:
    command = ["xcrun", "simctl", "launch", "--terminate-running-process",
               device, bundle, *args]
    output_path = ROOT / (label + "-launch.txt")
    try:
        with output_path.open("w") as output_file:
            # Important: simctl sometimes prints a PID and THEN hangs until
            # CoreSimulator's app-launch handshake eventually times out.
            # subprocess.run(timeout) stops it instead of losing diagnostics.
            result = subprocess.run(command, stdout=output_file,
                                    stderr=subprocess.STDOUT, timeout=25)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
        with output_path.open("a") as output_file:
            output_file.write("\nSIMCTL LAUNCH HANDSHAKE TIMED OUT AFTER 25 SECONDS\n")
    except OSError as error:
        code = 126
        with output_path.open("a") as output_file:
            output_file.write("\nLAUNCH EXCEPTION: " + str(error) + "\n")

    output = output_path.read_text(errors="replace")
    pid = pid_from_output(output, bundle=bundle)
    print(f"{label}: simctl exit={code}, PID={pid}, output={output[-1500:]}", flush=True)
    if code == 0 and pid:
        # Distinguish a slow CoreSimulator foreground transition from a white
        # native screen. This delay is only for cloud screenshots, never for UI.
        time.sleep(11 if label != "01-minimal-probe" else 7)
        (ROOT / (label + "-process.txt")).write_text(
            bounded(["ps", "-p", str(pid), "-o", "pid=,comm="], seconds=4)[1]
        )
        alive = still_alive(pid)
        print(f"{label}: alive after 7 seconds={alive}", flush=True)
        if alive:
            screenshot = ROOT / (label + ".png")
            evidence = ROOT / (label + "-render-verification.txt")
            # Cold-run iPhone simulators can return white screenshots despite
            # successful process launch. Wait for *visible pixels*, not just a PID.
            for attempt in range(4):
                if screenshot.exists():
                    screenshot.unlink()
                capture_code, capture_log = bounded(
                    ["xcrun", "simctl", "io", device, "screenshot", str(screenshot)],
                    seconds=17)
                with (ROOT / (label + "-screenshot-log.txt")).open("a") as log_file:
                    log_file.write(f"Attempt {attempt + 1}: {capture_log}\n")
                if capture_code == 0 and screenshot.exists() and screenshot.stat().st_size > 1000:
                    check_code, check_output = bounded(
                        ["build/validate-screenshot", str(screenshot)], seconds=7)
                    with evidence.open("a") as report:
                        report.write(f"Attempt {attempt + 1}: {check_output}\n")
                    if check_code == 0:
                        print(f"{label}: actual UI image verified after {attempt + 1} attempt(s)", flush=True)
                        return True
                    print(f"{label}: screenshot is still blank (attempt {attempt + 1})", flush=True)
                else:
                    print(f"{label}: screenshot capture failed (attempt {attempt + 1}, code={capture_code})", flush=True)
                if attempt < 3 and still_alive(pid):
                    time.sleep(8)
                else:
                    break
    # Always capture failure logs, whether simctl returned an error, returned a
    # dead PID, or hung. This avoids misleading green builds.
    capture_crashes(device, label)
    print(f"{label}: FAILED; saved diagnostic files under {ROOT}", flush=True)
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("device", help="Simulator UDID obtained by simctl")
    parser.add_argument("--runner-probe", help="Optional stand-alone baseline app for isolating hosted simulator faults")
    options = parser.parse_args()
    device = options.device
    if options.runner_probe:
        rc, output = bounded(["xcrun", "simctl", "install", device, options.runner_probe], seconds=35)
        (ROOT / "00-host-baseline-install.txt").write_text(output)
        if rc != 0:
            print("Could not install independent simulator baseline", flush=True)
            return 3
        if not launch(device, "00-host-baseline", [], bundle="com.fieldos.runnerprobe"):
            print("Even a dependency-free SwiftUI app failed; suspect hosted simulator environment.", flush=True)
            return 3
    if not launch(device, "01-minimal-probe", ["-FIELDStartupProbe"]):
        return 1
    # Same genuine DashboardView, minus RootView's TabView container. This
    # distinguishes native dashboard rendering from a full-root problem.
    if not launch(device, "02-isolated-real-dashboard", ["-FIELDIsolatedDashboard"]):
        return 2
    if not launch(device, "03-native-dashboard", ["-FIELDRenderOnly"]):
        return 3
    if not launch(device, "04-native-map", ["-FIELDPreviewMap", "-FIELDRenderOnly"]):
        return 4
    if not launch(device, "05-native-route-planner", ["-FIELDPreviewRoute", "-FIELDRenderOnly"]):
        return 5
    print("Minimal app, isolated real dashboard, full dashboard, map and route planner all rendered.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
