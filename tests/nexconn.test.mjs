import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {channelForIssue,chatUserForProfile,closedGroupPermissions,workflowMessage,signedHeaders,webhookIdentity} from '../lib/nexconn-protocol.ts';

const testKey='unit-test-key', testSecret='unit-test-secret';
function delivery() {
  const signed=signedHeaders(testKey,testSecret);
  return new Headers({AppKey:testKey,Nonce:signed.Nonce,Timestamp:signed.Timestamp,Signature:signed.Signature});
}
test('provider signing uses documented SHA-1 order, milliseconds, nonce length and fresh request identities',()=>{
  const one=signedHeaders(testKey,testSecret), two=signedHeaders(testKey,testSecret);
  assert.equal(one['App-Key'],testKey);
  assert.match(one.Nonce,/^[a-f0-9]{18}$/);
  assert.match(one.Timestamp,/^\d{13}$/);
  assert.equal(one.Signature,createHash('sha1').update(testSecret+one.Nonce+one.Timestamp).digest('hex'));
  assert.notEqual(one.Nonce,two.Nonce);
  assert.notEqual(one['X-Request-ID'],two['X-Request-ID']);
  assert.equal(Object.values(one).includes(testSecret),false);
});
test('fresh authentic webhook produces a consistent replay identity and rejects forged or stale headers',()=>{
  const valid=delivery();
  assert.match(webhookIdentity(valid,testKey,testSecret),/^[a-f0-9]{64}$/);
  assert.equal(webhookIdentity(valid,testKey,testSecret),webhookIdentity(new Headers(valid),testKey,testSecret));
  assert.equal(webhookIdentity(valid,testKey,testSecret,Number(valid.get('Timestamp'))+300001),null);
  for(const [key,value] of Object.entries({AppKey:'other',Nonce:'changed',Timestamp:'0',Signature:'0'.repeat(40)})){
    const changed=new Headers(valid);changed.set(key,value);assert.equal(webhookIdentity(changed,testKey,testSecret),null);
  }
  assert.equal(webhookIdentity(valid,testKey,undefined),null);
});
test('room and user IDs are deterministic, distinct, alphanumeric, and groups restrict joining and invitations',()=>{
  const id='f905cb8a-0581-4f58-9791-5ad754c456bd';
  assert.equal(channelForIssue(id),'if905cb8a05814f5897915ad754c456bd');
  assert.equal(chatUserForProfile(id),'uf905cb8a05814f5897915ad754c456bd');
  assert.deepEqual(closedGroupPermissions,{joinPerm:3,removePerm:0,memInvitePerm:0,profilePerm:0,invitePerm:0});
});

test('workflow delivery targets one group, persists a stable audit ID and filters private event metadata',()=>{
  const event={id:'an-audit-id',channel:'an-issue',action:'evidence_attached',kind:'file',
    actor:'ca9861ee-2957-4f61-8316-5187575340af',privateUrl:'signed-private-file',notes:'private notes'};
  const first=workflowMessage(event);
  assert.deepEqual(first,workflowMessage(event));
  assert.deepEqual(first.toChannelIds,[event.channel]);
  assert.equal(first.fromUserId,'ApexResolveWorkflow');
  assert.equal(first.messageType,'Apex:Workflow');
  assert.equal(first.shouldPersist,1);
  assert.deepEqual(JSON.parse(first.content),{eventId:event.id,action:event.action,detail:'file · By member ca9861ee'});
});
