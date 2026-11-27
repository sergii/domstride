// Node standard library only. Does not import Domstride or its execution runtime.
const fs = require("node:fs");
const path = require("node:path");

function writeCase(root, metadata, videos = []) {
  if (!["passed","failed","skipped","pending","unknown"].includes(metadata.status) ||
      typeof metadata.name !== "string" || !metadata.name || Buffer.byteLength(metadata.name)>1024 ||
      !Number.isFinite(metadata.duration_ms) || metadata.duration_ms<0 ||
      !Array.isArray(videos) || videos.length>4) throw new Error("Invalid case manifest");
  const item = {format:"domstride.case",schema_version:1,name:metadata.name,status:metadata.status,duration_ms:metadata.duration_ms};
  for (const key of ["producer","framework","runner","platform","language"]) {
    if (metadata[key] == null) continue;
    if (typeof metadata[key]!=="string" || !metadata[key] || Buffer.byteLength(metadata[key])>128) throw new Error("Invalid case metadata");
    item[key]=metadata[key];
  }
  for (const key of ["assertions","steps","assertion_events"]) if (metadata[key] !== undefined) item[key]=metadata[key];
  fs.mkdirSync(root,{recursive:true,mode:0o700});
  const directory=fs.mkdtempSync(path.join(root,"domstride-case-"));
  try {
    item.videos=videos.map((video,i)=>{
      if(typeof video.label!=="string" || !video.label || Buffer.byteLength(video.label)>128) throw new Error("Invalid video label");
      const stat=fs.lstatSync(video.path);
      if(!stat.isFile() || stat.size>8*1024*1024) throw new Error("Invalid video file");
      const bytes=fs.readFileSync(video.path);
      if(bytes.length>8*1024*1024 || !bytes.subarray(0,4).equals(Buffer.from([0x1a,0x45,0xdf,0xa3])) ||
        !bytes.subarray(0,256).includes(Buffer.from([0x42,0x82,0x84,0x77,0x65,0x62,0x6d]))) throw new Error("Expected WebM");
      const file="video-"+String(i+1).padStart(2,"0")+".webm";
      fs.writeFileSync(path.join(directory,file),bytes,{flag:"wx",mode:0o600});
      return {file,label:video.label,...(video.cues===undefined?{}:{cues:video.cues})};
    });
    const json=JSON.stringify(item);
    if(Buffer.byteLength(json)>256*1024) throw new Error("Case manifest exceeds limit");
    fs.writeFileSync(path.join(directory,"case.json"),json,{flag:"wx",mode:0o600});
    return directory;
  } catch(error) {
    fs.rmSync(directory,{recursive:true,force:true});
    throw error;
  }
}
module.exports={writeCase};
