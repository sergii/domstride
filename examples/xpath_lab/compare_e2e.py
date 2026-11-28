"""Balanced same-runner comparison. Memory is GNU time max RSS, not aggregate process-tree RSS."""
import json
import os
from pathlib import Path
import statistics
import subprocess
import time

out = Path("xpath-e2e-results")
out.mkdir(exist_ok=True)
engines = ["jsdom", "jsdom31", "happy-dom"]
results = []
for round_index in range(3):
    for engine in engines[round_index:] + engines[:round_index]:
        name = f"{round_index + 1}-{engine}"
        env = dict(os.environ)
        env.update(SPECDRIVE_ENGINE=engine, XPATH_LAB_CANDIDATE="xpath", XPATH_LAB_TRACE="0",
                   SPECDRIVE_RUNTIME="node", SPECDRIVE_QUERY_PREFETCH="0", SPECDRIVE_PROFILE="0",
                   SPECDRIVE_CLOCK="real", SPECDRIVE_BUNDLE_CACHE="off", SPECDRIVE_REUSE_WORKER="0")
        for key in ("SPECDRIVE_RECORD_DIR", "DOMSTRIDE_RECORD_DIR"):
            env.pop(key, None)
        start = time.monotonic()
        with (out / f"{name}.stdout").open("w") as stdout, (out / f"{name}.stderr").open("w") as stderr:
            result = subprocess.run(["/usr/bin/time", "-f", "%M", "-o", str(out / f"{name}.rss-kib"),
                                     "bundle", "exec", "ruby", "-Ilib", "examples/xpath_lab/e2e_benchmark.rb"],
                                    env=env, stdout=stdout, stderr=stderr, timeout=150)
        elapsed = time.monotonic() - start
        entry = {"round": round_index + 1, "engine": engine, "exit": result.returncode, "process_wall_seconds": elapsed}
        if result.returncode == 0:
            data = json.loads((out / f"{name}.stdout").read_text().strip().splitlines()[-1])
            assert data["engine"] == engine and data["persistence_checked"]
            assert data["settings"]["engine"] == engine
            assert data["iterations"] == 5 and data["repeats"] == 3
            assert len(data["samples"]) == 3 and all(x > 0 for x in data["samples"])
            entry.update(data, max_rss_kib=int((out / f"{name}.rss-kib").read_text().strip()))
        results.append(entry)
        print(json.dumps(entry), flush=True)
        (out / "runs.json").write_text(json.dumps(results, indent=2))
summary = {}
for engine in engines:
    runs = [r for r in results if r["engine"] == engine and r["exit"] == 0]
    if len(runs) == 3:
        summary[engine] = {"median_seconds_per_five_scenarios": statistics.median(
            statistics.median(r["samples"]) for r in runs),
            "median_max_rss_kib": statistics.median(r["max_rss_kib"] for r in runs)}
(out / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
if len(summary) != len(engines):
    raise SystemExit("At least one engine did not complete the correctness-checked benchmark")
