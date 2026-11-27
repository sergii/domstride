"""Reference-only visual matching against decoded media PTS, not callback receive time."""
import json
import math
import pathlib
import subprocess
import sys

def inspect_video(video, observations):
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames", "-show_streams",
        "-show_entries", "frame=best_effort_timestamp_time:stream=width,height", "-of", "json", str(video)
    ]))
    stream = probe["streams"][0]
    width, height = stream["width"], stream["height"]
    pts = [float(f["best_effort_timestamp_time"]) for f in probe["frames"]]
    if not pts or any(not math.isfinite(t) for t in pts) or any(b <= a for a, b in zip(pts, pts[1:])):
        raise ValueError("Invalid or non-monotonic decoded presentation timestamps")
    targets = observations["targets"]
    def green(frame, x, y):
        if not (0 <= x < width and 0 <= y < height):
            return False
        i = (y * width + x) * 3
        r, g, b = frame[i:i+3]
        return r < 80 and 95 < g < 205 and 50 < b < 155 and g-r > 65 and g-b > 20
    def score(frame, target):
        if target["viewport"] != {"width": width, "height": height}:
            return False
        rect = target["bounds"]
        x, y, w, h = [rect[k] for k in ("x", "y", "width", "height")]
        if min(w, h) < 15:
            return False
        # Avoid rounded corners; inspect expected outline bands, with compression tolerance.
        sides = [
            [(round(x+w*f),round(y-5.5),0,1) for f in [i/20 for i in range(4,17)]],
            [(round(x+w*f),round(y+h+5.5),0,1) for f in [i/20 for i in range(4,17)]],
            [(round(x-5.5),round(y+h*f),1,0) for f in [i/20 for i in range(4,17)]],
            [(round(x+w+5.5),round(y+h*f),1,0) for f in [i/20 for i in range(4,17)]],
        ]
        matches = []
        for side in sides:
            if any(not (3<=px<width-3 and 3<=py<height-3) for px,py,_,_ in side):
                continue
            matches.append(sum(any(green(frame,px+dx*d,py+dy*d) for d in range(-3,4)) for px,py,dx,dy in side)/len(side))
        return len(matches)>=3 and sum(m>=0.75 for m in matches)>=3
    hit = [[] for _ in targets]
    proc = subprocess.Popen(["ffmpeg","-v","error","-i",str(video),"-map","0:v:0","-f","rawvideo","-pix_fmt","rgb24","-fps_mode","passthrough","-"],stdout=subprocess.PIPE)
    size=width*height*3
    try:
        for index in range(len(pts)):
            frame=proc.stdout.read(size)
            if len(frame)!=size:
                raise ValueError("Decoded frame count mismatch")
            for i,target in enumerate(targets):
                if score(frame,target):
                    hit[i].append(index)
        if proc.stdout.read(1):
            raise ValueError("Unexpected extra decoded frames")
    finally:
        proc.stdout.close()
        if proc.wait()!=0:
            raise ValueError("Video decoding failed")
    results=[]
    for target,indices in zip(targets,hit):
        entry={"step_id":target["stepId"],"action":target["action"],"match":"unresolved"}
        # Refuse ambiguous repeated segments or isolated detections.
        if len(indices)>=3 and all(b==a+1 for a,b in zip(indices,indices[1:])):
            entry.update(match="candidate",first_visible_pts_ms=round((pts[indices[0]]-pts[0])*1000,3),
                         last_visible_pts_ms=round((pts[indices[-1]]-pts[0])*1000,3),frame_count=len(indices))
        results.append(entry)
    # Candidates are visual observations only. Reject overlapping or reordered intervals.
    valid=[e for e in results if e["match"]=="candidate"]
    if any(b["first_visible_pts_ms"]<=a["last_visible_pts_ms"] for a,b in zip(valid,valid[1:])):
        for e in valid:
            e["match"]="ambiguous"
    return {"format":"domstride.reference-focus-media-observations","schema_version":1,
            "timing_quality":"visual_candidates_unvalidated","method":"decoded_outline_match",
            "frame_count":len(pts),"media_origin_pts_ms":pts[0]*1000,"targets":results}

if __name__=="__main__":
    root=pathlib.Path(sys.argv[1])
    files=list(root.glob("*/domstride-case-*/focus-observations.json"))
    if len(files)!=1:
        raise ValueError("Expected exactly one guided focus observations file")
    source=files[0]
    result=inspect_video(source.parent/"video-01.webm",json.loads(source.read_text()))
    (source.parent/"focus-media-observations.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))
