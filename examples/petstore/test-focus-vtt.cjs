const assert=require('node:assert/strict');
const {timestamp,focusVtt}=require('./focus-vtt.cjs');
assert.equal(timestamp(3661234),'01:01:01.234');
assert.equal(focusVtt([{first_visible_pts_ms:2480,last_visible_pts_ms:3360,label:'Title'}]),'WEBVTT\n\n00:00:02.480 --> 00:00:03.360\nFocus: Title\n');
assert.throws(()=>focusVtt([{first_visible_pts_ms:100,last_visible_pts_ms:100,label:'bad'}]));
assert.throws(()=>focusVtt([{first_visible_pts_ms:100,last_visible_pts_ms:200,label:'a'},{first_visible_pts_ms:190,last_visible_pts_ms:300,label:'b'}]));
assert.equal(focusVtt([]),'WEBVTT\n\n\n');
console.log('Verified WebVTT timestamps and non-overlapping observed intervals');
