"""Reference-only visual matching against decoded media PTS, not callback receive time."""
import json
import math
import pathlib
import subprocess
import sys

def matches_outline(r, g, b, color):
    # Keep historic recordings readable; do not infer a new color from the UI theme.
    if color == "#059669":
        return r < 80 and 95 < g < 205 and 50 < b < 155 and g-r > 65 and g-b > 20
    if color == "#2563eb":
        return r < 100 and 45 < g < 155 and b > 175 and b-g > 65 and b-r > 100
    raise ValueError("Unsupported outline color")


def read_landmark(frame,width,height):
    # Marker is anchored to bottom-right, with fixed sync rows and eight binary cells.
    if width!=1280 or height!=800:
        return None
    def cell(i):
        x=width-40+(i%4)*8+4
        y=height-40+(i//4)*8+4
        offset=(y*width+x)*3
        r,g,b=frame[offset:offset+3]
        if r>160 and g<100 and b>160:return "M"
        if r<100 and g>160 and b>160:return "C"
        if min(r,g,b)>180:return "1"
        if max(r,g,b)<70:return "0"
        return "?"
    cells=[cell(i) for i in range(16)]
    if cells[:4]!=list("MCMC") or cells[12:]!=list("CMCM") or any(c not in "01" for c in cells[4:12]):
        return None
    return int("".join(cells[4:12]),2)

def step_intervals(markers,hits,pts):
    result=[]
    for start,end in zip(markers[::2],markers[1::2]):
        if start["step_id"]!=end["step_id"] or start["boundary"]!="start" or end["boundary"]!="end":
            raise ValueError("Invalid step landmark sequence")
        a,b=hits.get(start["code"],[]),hits.get(end["code"],[])
        if len(a)<2 or len(b)<2 or a[-1]>=b[0]:continue
        if any(y!=x+1 for seq in [a,b] for x,y in zip(seq,seq[1:])):continue
        start_ms=round((pts[a[0]]-pts[0])*1000,3)
        end_ms=round((pts[b[-1]]-pts[0])*1000,3)
        if result and start_ms<=result[-1]["end_ms"]:raise ValueError("Overlapping step landmarks")
        result.append({"step_id":start["step_id"],"start_ms":start_ms,"end_ms":end_ms})
    return result

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
    outline_color = observations.get("outline_color", "#059669")
    if outline_color not in ("#059669", "#2563eb"):
        raise ValueError("Unsupported outline color")
    def outline_pixel(frame, x, y):
        if not (0 <= x < width and 0 <= y < height):
            return False
        i = (y * width + x) * 3
        r, g, b = frame[i:i+3]
        return matches_outline(r, g, b, outline_color)
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
            matches.append(sum(any(outline_pixel(frame,px+dx*d,py+dy*d) for d in range(-3,4)) for px,py,dx,dy in side)/len(side))
        return len(matches)>=3 and sum(m>=0.75 for m in matches)>=3
    hit = [[] for _ in targets]
    markers=observations.get('step_markers',[])
    if len(markers)%2 or len({m['code'] for m in markers})!=len(markers):raise ValueError('Invalid landmark list')
    marker_hits={m['code']:[] for m in markers}
    proc = subprocess.Popen(["ffmpeg","-v","error","-i",str(video),"-map","0:v:0","-f","rawvideo","-pix_fmt","rgb24","-fps_mode","passthrough","-"],stdout=subprocess.PIPE)
    size=width*height*3
    try:
        for index in range(len(pts)):
            frame=proc.stdout.read(size)
            if len(frame)!=size:
                raise ValueError("Decoded frame count mismatch")
            if markers:
                code=read_landmark(frame,width,height)
                if code in marker_hits:marker_hits[code].append(index)
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
            "timing_quality":"visual_candidates_unvalidated","method":"decoded_outline_match","outline_color":outline_color,
            "frame_count":len(pts),"media_origin_pts_ms":pts[0]*1000,"targets":results,
            "step_intervals":step_intervals(markers,marker_hits,pts)}

if __name__=="__main__":
    root=pathlib.Path(sys.argv[1])
    files=list(root.glob("*/domstride-case-*/focus-observations.json"))
    if len(files)!=1:
        raise ValueError("Expected exactly one guided focus observations file")
    source=files[0]
    result=inspect_video(source.parent/"video-01.webm",json.loads(source.read_text()))
    (source.parent/"focus-media-observations.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))
