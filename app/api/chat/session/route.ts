import { NextResponse } from 'next/server';
import { z } from 'zod';
import { configured, db, storageAdmin } from '@/lib/db';
import { chatConfig,openRoom,openDirect,openGroup,dismissCommunity } from '@/lib/nexconn';

function reply(body:object,status:number) {
  return NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
}
export async function POST(request:Request) {
  if (!configured()) return reply({error:'Configure Supabase to connect this room.'},503);
  if (request.headers.get('origin') !== 'http://' + request.headers.get('host') && request.headers.get('origin') !== 'https://' + request.headers.get('host')) return reply({error:'Invalid origin.'},403);
  const input=z.union([z.object({issueId:z.uuid()}).strict(),z.object({peerId:z.uuid()}).strict(),z.object({communityId:z.uuid()}).strict()]).safeParse(await request.json().catch(()=>null));
  if (!input.success) return reply({error:'Invalid room.'},400);
  try {
    const client=await db(), {data:{user}}=await client.auth.getUser();
    if (!user) return reply({error:'Sign in to connect.'},401);
    try { chatConfig(); } catch { return reply({error:'Configure the Nexconn App Key, App Secret, region and Supabase server key to connect.'},503); }
    const limit=await storageAdmin().rpc('take_chat_session',{p_user:user.id});
    if (limit.error) throw new Error('Database unavailable.');
    if (!limit.data) return reply({error:'Too many connection attempts. Retry in one minute.'},429);
    const name=typeof user.user_metadata?.display_name==='string' ? user.user_metadata.display_name.trim() : '';
    if('communityId' in input.data){
      const id=input.data.communityId;
      const access=await client.from('workspace_members').select('role,workspaces(name,community_state)').eq('workspace_id',id).eq('user_id',user.id).maybeSingle();
      if(access.error)throw new Error('Community unavailable.');
      if(!access.data || access.data.role==='guest')return reply({error:'Community membership required.'},403);
      const joined=access.data.workspaces;
      const group=Array.isArray(joined)?joined[0]:joined;
      if(group?.community_state!=='active')return reply({error:'This community is closed.'},410);
      const result=await openGroup(user.id,'c'+id.replaceAll('-',''),group.name,name||'Member');
      const latest=await client.from('workspaces').select('community_state').eq('id',id).single();
      if(latest.error)throw new Error('Community unavailable.');
      if(latest.data.community_state!=='active'){
        await dismissCommunity(id);
        return reply({error:'This community is closed.'},410);
      }
      return reply(result,200);
    }
    if('peerId' in input.data) {
      const peer=await storageAdmin().from('profiles').select('id,display_name').eq('id',input.data.peerId).maybeSingle();
      if(peer.error)throw new Error('Directory unavailable.');
      if(!peer.data || peer.data.id===user.id)return reply({error:'Member unavailable.'},404);
      const contact=await client.from('contact_requests').select('id').eq('status','accepted').or('sender.eq.'+peer.data.id+',recipient.eq.'+peer.data.id).maybeSingle();
      if(contact.error||!contact.data)return reply({error:'This conversation requires approval.'},403);
      const session=await openDirect(user.id,contact.data.id,name||'Member');
      return reply({...session,peerName:peer.data.display_name||'Team member'},200);
    }
    const issue=await client.from('issues').select('id,title,channel_id').eq('id',input.data.issueId).maybeSingle();
    if (issue.error) throw new Error('Database unavailable.');
    if (!issue.data) return reply({error:'Room unavailable.'},404);
    return reply(await openRoom(issue.data,user.id,name || 'Member '+user.id.slice(0,8)),200);
  } catch { return reply({error:'Could not open the Nexconn room. Check service configuration and try again.'},503); }
}
