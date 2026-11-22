import 'server-only';
import { z } from 'zod';
import { db } from './db';

// Call only after checking the user's analysis consent. RLS checks room access again.
export async function readRoomContext(issueId:string,limit=50):Promise<string[]> {
  const id=z.uuid().parse(issueId), count=z.number().int().min(1).max(50).parse(limit);
  const client=await db();
  const {data:access,error:accessError}=await client.rpc('can_access_issue',{p_issue_id:id});
  if(accessError || !access)throw new Error('Room access required.');
  const {data,error}=await client.from('room_context').select('body')
    .eq('issue_id',id).not('body','is',null).order('sent_at',{ascending:false}).order('message_id',{ascending:false}).limit(count);
  if(error)throw new Error('Could not retrieve room context.');
  return z.array(z.object({body:z.string()})).parse(data).reverse().map(row=>row.body);
}
