import { createHash } from 'node:crypto';
import { webhookIdentity } from '@/lib/nexconn-protocol';
import { z } from 'zod';
import { storageAdmin } from '@/lib/db';

const envelope=z.object({type:z.string(),data:z.array(z.unknown()).max(100)});
const sent=z.object({channelType:z.number(),channelId:z.string(),messageType:z.string(),content:z.string(),
  messageId:z.string().max(256),time:z.number().int().positive(),userId:z.string(),
  groupUserIds:z.array(z.string()).optional(),profanityType:z.number().optional()});
const removed=z.object({channelInfo:z.object({channelType:z.number(),channelId:z.string()}),
  originalMsgInfo:z.object({messageId:z.string().max(256),messageTime:z.number().int().positive()})});
export async function POST(request:Request) {
  const identity=webhookIdentity(request.headers,process.env.NEXT_PUBLIC_NEXCONN_APP_KEY,process.env.NEXCONN_APP_SECRET);
  if(!identity)return new Response(null,{status:401});
  const raw=await request.text();
  if(Buffer.byteLength(raw)>262144)return new Response(null,{status:413});
  let decoded:unknown;
  try{decoded=JSON.parse(raw);}catch{return new Response(null,{status:400});}
  const body=envelope.safeParse(decoded);
  if(!body.success)return new Response(null,{status:400});
  try {
    const binding=await storageAdmin().rpc('bind_chat_webhook',{p_identity:identity,p_digest:createHash('sha256').update(raw).digest('hex')});
    if(binding.error)throw Error();
    if(!binding.data)return new Response(null,{status:403});
    for(const item of body.data.data){
      let channel:string,id:string,time:number,text:string|null;
      if(body.data.type==='message:send'){
        const parsed=sent.safeParse(item);
        if(!parsed.success)return new Response(null,{status:400});
        const m=parsed.data;
        if(m.channelType!==3 || m.messageType!=='RC:TxtMsg' || m.groupUserIds?.length || m.profanityType===1 || !/^u[a-f0-9]{32}$/.test(m.userId))continue;
        let content:unknown;
        try{content=JSON.parse(m.content);}catch{continue;}
        const value=z.object({content:z.string().min(1)}).safeParse(content);
        if(!value.success)continue;
        channel=m.channelId; id=m.messageId; time=m.time; text=value.data.content.slice(0,2000);
      }else if(body.data.type==='message:delete'){
        const result=removed.safeParse(item);
        if(!result.success)return new Response(null,{status:400});
        if(result.data.channelInfo.channelType!==3)continue;
        channel=result.data.channelInfo.channelId;id=result.data.originalMsgInfo.messageId;time=result.data.originalMsgInfo.messageTime;
        // Omit deleted content from future analyses, including a user's personal deletion.
        text=null;
      }else continue;
      if(!/^i[a-f0-9]{32}$/.test(channel))continue;
      const {error}=await storageAdmin().rpc('record_room_message',{p_channel:channel,p_id:id,p_time:time,p_body:text});
      if(error)throw Error();
    }
    return new Response(null,{status:204});
  } catch{return new Response(null,{status:503});}
}
