import 'server-only';
import { randomUUID } from 'node:crypto';
import { signedHeaders, closedGroupPermissions, channelForIssue, chatUserForProfile, workflowSender, workflowMessage } from './nexconn-protocol';
import { z } from 'zod';
import { storageAdmin } from './db';

const hosts = { SG: 'api.sg-light-api.com', NA: 'api.us-light-api.com', SA: 'api.sau-light-api.com' } as const;
export function chatConfig() {
  const region = z.enum(['SG','NA','SA']).parse(process.env.NEXCONN_REGION || 'SG');
  const appKey = process.env.NEXT_PUBLIC_NEXCONN_APP_KEY, secret = process.env.NEXCONN_APP_SECRET;
  if (!appKey || !secret || !process.env.SUPABASE_SECRET_KEY) throw new Error('Chat configuration is incomplete.');
  return { region, appKey, secret };
}

async function call(path: string, body: object, allowed: number[] = []) {
  const { region, appKey, secret } = chatConfig();
  const response = await fetch('https://' + hosts[region] + '/v4/' + path, {
    method: 'POST', cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(5000),
    headers: signedHeaders(appKey, secret), body: JSON.stringify(body)
  });
  const data = z.object({code:z.number(),result:z.unknown().optional()}).parse(await response.json());
  if (data.code !== 0 && !allowed.includes(data.code)) throw new Error('Nexconn request failed.');
  if (!response.ok && data.code === 0) throw new Error('Nexconn transport failed.');
  return data;
}
async function issueToken(userId:string, name:string) {
  const response = await call('auth/access-token/issue',{ userId, name:name.slice(0,64) });
  return z.object({userId:z.literal(userId),accessToken:z.string().min(1)}).parse(response.result).accessToken;
}
async function ensureClosedGroup(channelId:string,title:string){
    // A reserved server identity owns every channel. App users cannot approve join requests.
    await issueToken(workflowSender,'Apex Resolve');
    const created = await call('group-channel/create',{
      channelId, name:title.slice(0,64), owner:workflowSender,
      permissions:closedGroupPermissions
    },[25409]);
    if (created.code === 25409) {
      const match = await call('group-channel/profile/list',{channelIds:[channelId]});
      const profile = z.object({profiles:z.array(z.object({channelId:z.string(),owner:z.string(),permissions:z.object({joinPerm:z.number(),memInvitePerm:z.number()})}))}).parse(match.result);
      if (!profile.profiles.some(p => p.channelId===channelId && p.owner===workflowSender && p.permissions.joinPerm===3 && p.permissions.memInvitePerm===0)) throw new Error('Channel ownership mismatch.');
    }
}

export async function dismissCommunity(id:string) {
  const channelId='c'+id.replaceAll('-','');
  try {
    await call('group-channel/dismiss',{channelId});
  } catch {
    // An unopened community or a retried dismissal can already be absent.
    const result=await call('group-channel/profile/list',{channelIds:[channelId]});
    const {profiles}=z.object({profiles:z.array(z.object({channelId:z.string()}))}).parse(result.result);
    if(profiles.some(profile=>profile.channelId===channelId))throw new Error('Chat deletion is pending. Retry from Community info.');
  }
}

export async function openDirect(sender:string,contactId:string,name:string) {
  return openGroup(sender,'d'+contactId.replaceAll('-',''),'Private conversation',name);
}
export async function openGroup(sender:string,channelId:string,title:string,name:string){
  const {region,appKey}=chatConfig();
  const userId=chatUserForProfile(sender);
  const [,token]=await Promise.all([ensureClosedGroup(channelId,title),issueToken(userId,name)]);
  await call('group-channel/join',{channelId,userIds:[userId]},[25412]);
  return {region,appKey,userId,channelId,token};
}
export async function openRoom(issue:{id:string; title:string; channel_id:string|null}, authenticatedId:string, name:string) {
  const { region, appKey } = chatConfig();
  const userId = chatUserForProfile(authenticatedId);
  const channelId = channelForIssue(issue.id);
  if (issue.channel_id && issue.channel_id !== channelId) throw new Error('Unexpected room mapping.');
  if (!issue.channel_id) {
    await ensureClosedGroup(channelId,issue.title);
    const admin = storageAdmin();
    const {error} = await admin.from('issues').update({channel_id:channelId}).eq('id',issue.id).is('channel_id',null);
    if (error) throw new Error('Could not persist room mapping.');
  }
  const token = await issueToken(userId,name);
  await call('group-channel/join',{channelId,userIds:[userId]},[25412]);
  return { token, userId, channelId, region, appKey };
}
export async function publishEvents(issueId:string|null) {
  const admin = storageAdmin(), lease = randomUUID();
  const {data,error} = await admin.rpc('claim_chat_events',{p_issue:issueId,p_lease:lease});
  if (error) throw new Error('Outbox unavailable.');
  const events = z.array(z.object({event_id:z.uuid(),channel:z.string(),event_action:z.string(),details:z.unknown()})).parse(data);
  let delivered = 0;
  for (const row of events) {
    const info = z.object({title:z.string().optional(),status:z.string().optional(),kind:z.string().optional(),to:z.string().optional(),actor_id:z.string().optional(),assignee_id:z.string().nullish()}).parse(row.details);
    const response = await call('group-channel/message/send',workflowMessage({
      id:row.event_id,channel:row.channel,action:row.event_action,title:info.title,kind:info.kind,
      status:info.status || info.to,actor:info.actor_id,assignee:info.assignee_id,
    }));
    const ack = z.object({messageIds:z.array(z.object({channelId:z.string(),messageId:z.string().min(1)}))}).parse(response.result);
    if (!ack.messageIds.some(entry=>entry.channelId===row.channel)) throw new Error('Missing delivery acknowledgement.');
    const result = await admin.from('outbox_events').update({published_at:new Date().toISOString(),lease_id:null,lease_until:null})
      .eq('id',row.event_id).eq('lease_id',lease);
    if (result.error) throw new Error('Could not acknowledge delivery.');
    delivered++;
  }
  return delivered;
}
