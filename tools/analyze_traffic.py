#!/usr/bin/env python3
import sys
import re
from collections import Counter

def parse_line(line):
    # Support structured lines produced by the traffic client, for example:
    # 2026-10-08T12:00:00+00:00 status=200 time=0.123 body={"version":"v1","instance":"pod-..."}
    # or fallback where body may be empty.
    line = line.strip()
    if not line:
        return None
    # status can be in two formats produced by different clients: 'status=200' or 'status:200', or 'ERR'
    m_status = re.search(r"status=(\d+|ERR)", line)
    if not m_status:
        m_status = re.search(r"status:(\d{3})", line)
    status = None
    if m_status:
        s = m_status.group(1)
        status = int(s) if s.isdigit() else None
    m_time = re.search(r"time=([0-9\.]+)", line)
    time_total = float(m_time.group(1)) if m_time else None
    # JSON body may appear either as body={...} (new format) or as a bare {..} on its own line
    m_json = re.search(r"body=(\{.*\})", line) or re.search(r"(\{.*\})", line)
    version = None
    instance = None
    if m_json:
        try:
            import json
            j = json.loads(m_json.group(1))
            version = j.get("version")
            instance = j.get("instance")
        except Exception:
            pass
    return {"raw": line, "status": status, "time": time_total, "version": version, "instance": instance}

def analyze(fp):
    total = 0
    failures = 0
    status_counter = Counter()
    version_counter = Counter()
    instances = Counter()
    for line in fp:
        rec = parse_line(line)
        if not rec:
            continue
        total += 1
        if rec["status"] is None or rec["status"] >= 400:
            failures += 1
        else:
            status_counter[rec["status"]] += 1
        if rec["version"]:
            version_counter[rec["version"]] += 1
        if rec["instance"]:
            instances[rec["instance"]] += 1

    print(f"total_requests: {total}")
    print(f"failures: {failures}")
    print("status_counts:")
    for s,c in status_counter.most_common():
        print(f"  {s}: {c}")
    print("versions seen:")
    for v,c in version_counter.most_common():
        print(f"  {v}: {c}")
    print("instances seen (top 10):")
    for inst,c in instances.most_common(10):
        print(f"  {inst}: {c}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        # open with simple BOM/encoding detection so UTF-16LE logs from Windows are handled
        import io
        path = sys.argv[1]
        with open(path, 'rb') as bf:
            raw = bf.read()

        # detect BOM
        if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
            encoding = 'utf-16'
        elif raw.startswith(b"\xef\xbb\xbf"):
            encoding = 'utf-8-sig'
        else:
            # try utf-8, otherwise fall back to utf-16
            try:
                raw.decode('utf-8')
                encoding = 'utf-8'
            except Exception:
                encoding = 'utf-16'

        text = raw.decode(encoding, errors='replace')
        f = io.StringIO(text)
        analyze(f)
    else:
        import io
        text_stream = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8', errors='replace')
        analyze(text_stream)
