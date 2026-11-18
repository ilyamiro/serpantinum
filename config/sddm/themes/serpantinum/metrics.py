"""Provide current, non-user-specific hardware readings before login."""
import json
import os
from pathlib import Path
import time

ROOT = Path("/run/serpantinum-greeter-system")


def cpu():
    values = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]
    return sum(values), sum(values[3:5])


def read_metrics():
    before, idle_before = cpu()
    time.sleep(0.2)
    after, idle_after = cpu()
    memory = {key: int(value.split()[0]) for key, value in
              (line.split(":", 1) for line in Path("/proc/meminfo").read_text().splitlines())}
    disk = os.statvfs("/")
    temps = []
    for device in Path("/sys/class/hwmon").glob("hwmon*"):
        try:
            if (device / "name").read_text().strip() not in ("coretemp", "k10temp", "zenpower"):
                continue
            for reading in device.glob("temp*_input"):
                value = int(reading.read_text()) / 1000
                if 0 < value < 125:
                    temps.append(value)
        except (OSError, ValueError):
            continue
    return {
        "cpu": round(100 * (1 - (idle_after - idle_before) / max(1, after - before))),
        "ram": round(100 * (1 - memory["MemAvailable"] / memory["MemTotal"])),
        "disk": round(100 * (1 - disk.f_bavail / disk.f_blocks)),
        "temp": round(max(temps)) if temps else None,
    }


if __name__ == "__main__":
    pending = ROOT / "metrics.next"
    pending.write_text(json.dumps(read_metrics()) + "\n", encoding="utf-8")
    pending.replace(ROOT / "metrics.json")
