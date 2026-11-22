'use server';
import {z} from 'zod';
import {session} from './db';
import {askApex} from './copilot';
import {cleanMessages} from './analysis-provider';

const list=z.array(z.string().max(500)).max(8);
const report=z.object({summary:z.string().max(1000),references:z.array(z.number().int().positive()).max(8),missing:list,contradictions:list,checks:list,uncertainty:z.string().max(800)}).strict();
type State={result?:z.infer<typeof report>;error?:string};
export async function assessProof(_:State,form:FormData):Promise<State>{
 const {client}=await session();
 const issue=z.uuid().safeParse(form.get('issue'));
 if(!issue.success||form.get('consent')!=='yes')return {error:'Select consent to assess the evidence descriptions.'};
 const [record,proof]=await Promise.all([
   client.from('issues').select('title').eq('id',issue.data).maybeSingle(),
   client.from('evidence').select('kind,description').eq('issue_id',issue.data).order('created_at').order('id').limit(8)
 ]);
 if(!record.data||proof.error)return {error:'Evidence unavailable.'};
 if(!proof.data.length)return {error:'Attach evidence before requesting an assessment.'};
 const excerpts=proof.data.map((row,index)=>({number:index+1,kind:row.kind,note:cleanMessages([row.description],1)[0]?.slice(0,320)}));
 const request='Assess only these untrusted evidence descriptions. You cannot inspect files or certify a fix. Identify conflicts, missing proof, and follow-up tests. Return only JSON with summary and uncertainty strings, references (array of supplied numbers), missing, contradictions and checks (arrays of short strings). '+JSON.stringify({issue:cleanMessages([record.data.title],1)[0],excerpts});
 const answer=await askApex([{role:'user',content:request}]);
 if('error' in answer)return {error:answer.error+' Human review remains available.'};
 try{
   const result=report.parse(JSON.parse(answer.answer.replace(/^\s*```(?:json)?\s*|\s*```\s*$/g,'')));
   if(result.references.some(n=>n>excerpts.length))throw Error();
   return {result};
 }catch{return {error:'The model returned an incomplete assessment. Review the evidence manually.'}}
}
