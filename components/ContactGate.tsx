import LinkedConversationIssues from '@/components/LinkedConversationIssues';
import {redirect} from 'next/navigation';
import Link from 'next/link';
import {revalidatePath} from 'next/cache';
import {memberHandle} from '@/lib/handles';
import {session,storageAdmin} from '@/lib/db';
import RoomChat from './RoomChat';
import {RoomTranscriptProvider} from './RoomTranscript';

async function act(form:FormData){
  'use server';
  const {client}=await session(),peer=String(form.get('peer'));
  const {data,error}=await client.rpc('contact_action',{peer,operation:form.get('operation'),supplied_pin:String(form.get('pin')||'')});
  revalidatePath('/communication');
  redirect('/communication?tab=people&peer='+encodeURIComponent(peer)+(error?'&notice=unavailable':data==='invalid'?'&notice=invalid':''));
}
export async function ContactRequests(){
  const {client,user}=await session();
  const {data}=await client.from('contact_requests').select('id,sender').eq('recipient',user.id).eq('status','pending').order('created_at',{ascending:false});
  if(!data?.length)return null;
  const {data:profiles}=await storageAdmin().from('profiles').select('id,display_name').in('id',data.map(row=>row.sender));
  const names=new Map(profiles?.map(profile=>[profile.id,profile.display_name]));
  return <nav className="request-inbox" aria-label="Message requests"><strong>Message requests · {data.length}</strong>{data.map(row=>{
    const name=names.get(row.sender)||'Team member';
    return <Link className="inbox-row" key={row.id} href={'/communication?tab=people&peer='+row.sender}><span>{name}<small>{memberHandle(row.sender,name)}</small></span> →</Link>;
  })}</nav>;
}
export async function ContactGate({peer,notice}:{peer:string;notice?:string}){
  const {client,user}=await session();
  const {data,error}=await client.from('contact_requests').select('id,status,recipient').or('sender.eq.'+peer+',recipient.eq.'+peer).maybeSingle();
  if(error)return <p role="status">{error.code==='PGRST205'?'Private chat setup is pending. The workspace administrator needs to apply the contact consent migration.':'Could not check chat access. Refresh to retry.'}</p>;
  if(data?.status==='accepted'){
    const {data:spaces}=await client.from('workspaces').select('id,name,workspace_members!inner(role,user_id)').eq('workspace_members.user_id',user.id).neq('workspace_members.role','guest').order('name');
    return <RoomTranscriptProvider key={peer}><RoomChat direct issueId={peer} destinations={spaces||[]} sourcePath={'/communication?contact='+data.id}/><LinkedConversationIssues source={'/communication?contact='+data.id}/></RoomTranscriptProvider>;
  }
  const incoming=data?.status==='pending'&&data.recipient===user.id;
  return <section className="stack"><h3>{incoming?'Incoming chat request':'Private conversation'}</h3>
    <p>{incoming?'Accept to open a shared conversation.':'Enter their contact PIN or ask them to approve a chat.'}</p>
    {notice&&<p role="alert">{notice==='invalid'?'That PIN did not match.':'Could not update the request.'}</p>}
    <form action={act}><input type="hidden" name="peer" value={peer}/>
    {incoming?<><button name="operation" value="accept" className="btn btn-primary">Accept request</button> <button name="operation" value="decline" className="btn">Decline</button></>:<>
    <label>Contact PIN<input type="password" name="pin" autoComplete="off" maxLength={12}/></label><button name="operation" value="pin" className="btn btn-primary">Unlock chat</button>
    {data?<p>{data.status==='pending'?'Request sent · Awaiting approval':'Request declined'}</p>:<button name="operation" value="request" className="btn">Send message request</button>}</>}</form></section>;
}
