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
                 "--predicate", 'process == "FIELD iOS" OR subsystem == "com.fieldos.native" OR eventMessage CONTAINS[c] "com.fieldos.native"'],
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
    output_path = ROOT / (label + "-launch.txt")
    output_path.write_text("")
    # `simctl launch --terminate-running-process` has stalled even on the
    # FIRST launch on GitHub's free hosted Intel runner. End prior stages
    # explicitly so a new launch cannot silently reuse an old screenshot.
    if label != "01-minimal-probe":
        ended, note = bounded(
            ["xcrun", "simctl", "terminate", device, bundle], seconds=22)
        output_path.write_text(f"Prior-stage termination exit={ended}: {note}\n")
        if ended != 0:
            capture_crashes(device, label)
            print(f"{label}: simulator could not terminate previous stage (code={ended}); refusing stale screenshot", flush=True)
            return False
        time.sleep(3)
    command = ["xcrun", "simctl", "launch", device, bundle, *args]
    code = 126
    pid = None
    # Cold bootstatus can finish while SpringBoard is still accepting app
    # registrations. Retry ONLY failed launch handshakes, never fake a
    # successful foreground from a PID that simctl did not acknowledge.
    for attempt in range(3):
        try:
            with output_path.open("a") as output_file:
                output_file.write(f"Launch attempt {attempt + 1}\n")
                output_file.flush()
                result = subprocess.run(command, stdout=output_file,
                                        stderr=subprocess.STDOUT, timeout=38)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
            with output_path.open("a") as output_file:
                output_file.write("SIMCTL LAUNCH HANDSHAKE TIMED OUT AFTER 38 SECONDS\n")
        except OSError as error:
            code = 126
            with output_path.open("a") as output_file:
                output_file.write("LAUNCH EXCEPTION: " + str(error) + "\n")
        output = output_path.read_text(errors="replace")
        # Check only the latest launch attempt, not a stale PID from a
        # previous, timed-out attempt.
        latest = output.rsplit("Launch attempt ", 1)[-1]
        pid = pid_from_output(latest, bundle=bundle)
        print(f"{label}: attempt {attempt+1}/3, simctl exit={code}, PID={pid}, "
              f"output={latest[-600:]}", flush=True)
        if code == 0 and pid:
            break
        if attempt < 2:
            time.sleep(14)
    if code != 0 or pid is None:
        capture_crashes(device, label)
        print(f"{label}: launch never acknowledged by simulator", flush=True)
        return False
    if code == 0 and pid:
        # Distinguish a slow CoreSimulator foreground transition from a white
        # native screen. This delay is only for cloud screenshots, never for UI.
        time.sleep(11 if label != "01-minimal-probe" else 7)
        (ROOT / (label + "-process.txt")).write_text(
            bounded(["ps", "-p", str(pid), "-o", "pid=,comm="], seconds=4)[1]
        )
        alive = still_alive(pid)
        print(f"{label}: alive after foreground settle={alive}", flush=True)
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
