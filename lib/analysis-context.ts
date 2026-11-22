import {z} from 'zod';

const visibleMessage=z.object({
 id:z.string().min(1).max(256),
 text:z.string().min(1).max(2000),
 time:z.number().int().positive(),
}).strict();

// Browser history is a consented, user-scoped fallback for advisory analysis.
// It is never written into the shared Nexconn webhook mirror.
export function parseVisibleTranscript(value:FormDataEntryValue|null):string[] {
 if(typeof value!=='string'||value.length>125000)return [];
 try {
  const parsed=z.array(visibleMessage).max(50).safeParse(JSON.parse(value));
  if(!parsed.success)return [];
  const seen=new Set<string>();
  return parsed.data.filter(message=>{
   if(seen.has(message.id))return false;
   seen.add(message.id);
   return true;
  }).sort((a,b)=>a.time-b.time||a.id.localeCompare(b.id)).map(message=>message.text);
 } catch {return []}
}
