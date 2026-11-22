import { z } from 'zod';
import { configured,db } from '@/lib/db';
import { publishEvents } from '@/lib/nexconn';

export async function POST(request:Request) {
  if (request.headers.get('origin') !== 'http://' + request.headers.get('host') && request.headers.get('origin') !== 'https://' + request.headers.get('host')) return new Response(null,{status:403});
  const input=z.object({issueId:z.uuid()}).strict().safeParse(await request.json().catch(()=>null));
  if (!input.success) return new Response(null,{status:400});
  try {
    if (!configured()) return new Response(null,{status:503});
    const client=await db(), {data:{user}}=await client.auth.getUser();
    if (!user) return new Response(null,{status:401});
    const {data,error}=await client.rpc('can_access_issue',{p_issue_id:input.data.issueId});
    if (error) return new Response(null,{status:503});
    if (!data) return new Response(null,{status:404});
    await publishEvents(input.data.issueId);
    return new Response(null,{status:204});
  } catch { return new Response(null,{status:503}); }
}
export async function GET(request:Request) {
  if (!process.env.CRON_SECRET || request.headers.get('authorization')!=='Bearer '+process.env.CRON_SECRET)
    return new Response(null,{status:401});
  try { return Response.json({delivered:await publishEvents(null)},{headers:{'Cache-Control':'no-store'}}); }
  catch { return new Response(null,{status:503}); }
}
