import { createHash, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';

export const workflowSender = 'ApexResolveWorkflow';
export const closedGroupPermissions = {
  joinPerm: 3, removePerm: 0, memInvitePerm: 0, profilePerm: 0, invitePerm: 0,
} as const;
export const channelForIssue = (id: string) => 'i' + id.replaceAll('-', '');
export const chatUserForProfile = (id: string) => 'u' + id.replaceAll('-', '');

function signature(secret: string, nonce: string, timestamp: string) {
  return createHash('sha1').update(secret + nonce + timestamp).digest('hex');
}
export function signedHeaders(appKey: string, secret: string) {
  const nonce = randomBytes(9).toString('hex');
  const timestamp = String(Date.now());
  return {
    'App-Key': appKey, Nonce: nonce, Timestamp: timestamp,
    Signature: signature(secret, nonce, timestamp), 'X-Request-ID': randomUUID(),
    'Content-Type': 'application/json',
  };
}
export function webhookIdentity(headers: Headers, appKey?: string, secret?: string, now = Date.now()) {
  const nonce = headers.get('Nonce'), ts = headers.get('Timestamp'), sig = headers.get('Signature');
  if (!appKey || !secret || headers.get('AppKey') !== appKey || !nonce || nonce.length > 18 ||
    !ts || !/^\d{13}$/.test(ts) || Math.abs(now - Number(ts)) > 300000 ||
    !sig || !/^[a-f0-9]{40}$/.test(sig)) return null;

  const expected = Buffer.from(signature(secret, nonce, ts), 'hex');
  if (!timingSafeEqual(expected, Buffer.from(sig, 'hex'))) return null;
  // The provider signature covers these headers. PostgreSQL separately binds
  // this verified request identity to the first body observed over HTTPS.
  return createHash('sha256').update(JSON.stringify([appKey, nonce, ts])).digest('hex');
}

export function workflowMessage(row: {
  id:string; channel:string; action:string; title?:string; kind?:string;
  status?:string; actor?:string; assignee?:string|null;
}) {
  const detail = [row.title, row.kind, row.status,
    row.assignee && 'Assigned to member '+row.assignee.slice(0,8),
    row.actor && 'By member '+row.actor.slice(0,8),
  ].filter(Boolean).join(' · ').slice(0,400);
  return {
    fromUserId:workflowSender, toChannelIds:[row.channel], messageType:'Apex:Workflow',
    content:JSON.stringify({eventId:row.id,action:row.action,detail}),
    shouldPersist:1, disablePush:true,
  };
}
