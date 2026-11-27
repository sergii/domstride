type Size={width:number;height:number};
type RecorderPage={
 screencast:{start(options:{path:string;size:Size;onFrame?:(frame:{data:{length:number}})=>void}):Promise<void>;stop():Promise<void>};
 screenshot(options:{path:string;animations:'disabled'}):Promise<unknown>;
 url():string;
 waitForTimeout(ms:number):Promise<void>;
};
export class PlaywrightRecorder {
 constructor(options:{page:RecorderPage;directory:string;profile:'execution'|'guided';size:Size});
 screenshots:{stepId:string;file:string;url:string;phase:'after'}[];
 errors:string[];
 frameObservations:{sequence:number;bytes:number;receivedWallMs:number;receivedMonotonicMs:number}[];
 recordingWindow:{startWallMs:number;startMonotonicMs:number;endWallMs?:number;endMonotonicMs?:number}|null;
 presentationWaitMs:number;
 prepare():Promise<void>;
 start():Promise<void>;
 hold(ms:number):Promise<void>;
 checkpoint(stepId:string,holdMs?:number):Promise<void>;
 stop():Promise<void>;
 writeCapture(options?:{focusCount?:number}):Promise<void>;
}
