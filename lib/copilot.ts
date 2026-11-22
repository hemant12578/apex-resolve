'use server';
import {session} from './db';
import {z} from 'zod';

const turns=z.array(z.object({role:z.enum(['user','assistant']),content:z.string().trim().min(1).max(4000)})).min(1).max(12);
const windows=new Map<string,number[]>();
export async function askApex(input:unknown):Promise<{answer:string}|{error:string}>{
  const {user}=await session();
  const parsed=turns.safeParse(input);
  if(!parsed.success||parsed.data.at(-1)?.role!=='user')return {error:'Enter a message of up to 4,000 characters.'};
  const model=process.env.OPENROUTER_MODEL||'openrouter/free';
  if(process.env.AI_ENABLED!=='true'||!process.env.OPENROUTER_API_KEY||(model!=='openrouter/free'&&!model.endsWith(':free')))return {error:'Apex AI is unavailable in this environment.'};
  const now=Date.now();
  for(const [key,times] of windows)if(times.at(-1)!<=now-60000)windows.delete(key);
  const recent=(windows.get(user.id)||[]).filter(t=>t>now-60000);
  if(recent.length>=5)return {error:'Please wait a minute before sending another message.'};
  windows.set(user.id,[...recent,now]);
  try{
    const response=await fetch('https://openrouter.ai/api/v1/chat/completions',{method:'POST',redirect:'error',cache:'no-store',signal:AbortSignal.timeout(25000),headers:{Authorization:'Bearer '+process.env.OPENROUTER_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({model,max_tokens:600,messages:[{role:'system',content:'You are Apex AI, a concise collaboration assistant in Apex Resolve. You have access only to this conversation. Help draft replies, troubleshoot issues, translate text, and propose verification steps. Never claim you performed an action or verified evidence.'},...parsed.data]})});
    if(!response.ok)return {error:response.status===429?'The free model is busy. Try again shortly.':'OpenRouter could not answer. Please retry.'};
    const result=await response.json();
    const answer=z.string().trim().min(1).parse(result.choices?.[0]?.message?.content);
    return {answer:answer.slice(0,4000)};
  }catch{return {error:'Apex AI could not finish this reply. Try again.'}}
}
