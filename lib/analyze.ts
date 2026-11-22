'use server';
import {createHash} from 'node:crypto';
import {z} from 'zod';
import {session,storageAdmin} from './db';
import {readRoomContext} from './nexconn-history';
import {parseVisibleTranscript} from './analysis-context';
import {analyzeMessages,analysisSchema,cleanMessages,ProviderFailure,type AnalysisResult} from './analysis-provider';
export type AnalysisState={error?:string,id?:string,result?:AnalysisResult};
export async function analyze(_:AnalysisState,f:FormData):Promise<AnalysisState>{
 const {client,user}=await session();
 const id=z.uuid().safeParse(f.get('issue'));
 const primary='openrouter';
 if(process.env.AI_ENABLED!=='true')return {error:'AI is disabled in this deployment.'};
 if(!id.success||f.get('consent')!=='yes')return {error:'Select consent before analyzing this room.'};
 const {data:allowed}=await client.rpc('can_access_issue',{p_issue_id:id.data});
 if(!allowed)return {error:'Room access required.'};
 const allowFallback=false;
 const bounded=(key:string,defaultValue:number,max:number)=>{const v=Number(process.env[key]??defaultValue);return Number.isSafeInteger(v)&&v>0?Math.min(v,max):0};
 const limit=bounded('AI_MAX_CONTEXT_MESSAGES',50,50);
 if(!limit)return {error:'Check the configured context limit.'};
 let reservation='';
 try{
   const mirrored=await readRoomContext(id.data,limit);
   const messages=cleanMessages(mirrored.length?mirrored:parseVisibleTranscript(f.get('visibleTranscript')),limit);
   if(!messages.length)return {error:'No conversation text is available yet. Open this room, wait for its messages to load, and try again.'};
   const hash=createHash('sha256').update(JSON.stringify(['v2',messages,primary,allowFallback,process.env.OPENROUTER_MODEL])).digest('hex');
   const admin=storageAdmin(),{data,error}=await admin.rpc('begin_ai_analysis',{p_user:user.id,p_issue:id.data,p_context_hash:hash,p_daily_limit:bounded('AI_DAILY_LIMIT',3,100),p_daily_budget_micros:bounded('AI_DAILY_BUDGET_MICROS',0,1000000000),p_reserve_micros:bounded('AI_REQUEST_RESERVE_MICROS',100000,1000000000),p_allow_fallback:primary==='openrouter'||allowFallback});
   if(error)return {error:error.code==='P0001'?error.message:'Could not reserve analysis budget.'};
   if(data.state==='cached')return {id:data.id,result:analysisSchema.parse(data.result)};
   reservation=z.uuid().parse(data.id);
   const a=await analyzeMessages(messages,{gemini:false,openrouter:true,fallback:allowFallback},process.env);
   const {error:saveError}=await admin.rpc('finish_ai_analysis',{p_id:reservation,p_user:user.id,p_provider:a.provider,p_result:a.result,p_error:null,p_input_tokens:a.inputTokens,p_output_tokens:a.outputTokens});
   if(saveError)return {error:'Analysis could not be saved. Continue with manual tasks.'};
   return {id:reservation,result:a.result};
 }catch(e){
   if(reservation){await storageAdmin().rpc('finish_ai_analysis',{p_id:reservation,p_user:user.id,p_provider:e instanceof ProviderFailure?e.provider:null,p_result:null,p_error:e instanceof ProviderFailure?e.message:'analysis_failed',p_input_tokens:0,p_output_tokens:0})}
   return {error:'Analysis unavailable. Continue with manual tasks or retry later.'};
 }
}
