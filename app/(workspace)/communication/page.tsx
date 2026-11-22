import {contactList} from '@/lib/contact-list';
import {ContactGate,ContactRequests} from '@/components/ContactGate';
import {AtSign,Hash,MessagesSquare,SquarePen,ArrowLeft,ArrowUpRight,Search as SearchIcon} from 'lucide-react';
import {matchesMember,memberHandle} from '@/lib/handles';
import WorkspaceNav from '@/components/WorkspaceNav';
import Analysis from '@/components/Analysis';
import ApexAssistant from '@/components/ApexAssistant';
import Link from 'next/link';
import {notFound} from 'next/navigation';
import RoomChat from '@/components/RoomChat';
import {RoomTranscriptProvider} from '@/components/RoomTranscript';
import {rows,session,storageAdmin} from '@/lib/db';

type Search = {contact?:string;room?:string;peer?:string;tab?:string;q?:string;notice?:string;page?:string};
const pageSize=25;
export default async function Communication({searchParams}:{searchParams:Promise<Search>}) {
  const {client,user}=await session();
  const {room,peer:requestedPeer,contact,tab,q='',page,notice}=await searchParams;
  let peer=requestedPeer;
  if(contact){
    const {data}=await client.from('contact_requests').select('sender,recipient').eq('id',contact).eq('status','accepted').maybeSingle();
    if(!data || ![data.sender,data.recipient].includes(user.id))notFound();
    peer=data.sender===user.id?data.recipient:data.sender;
  }
  const term=q.trim().slice(0,100);
  const offset=(Math.max(1,Math.min(Number.parseInt(page||'1',10)||1,10000))-1)*pageSize;
  const chats=tab==='chats'||(!tab&&!room&&!peer&&!term.startsWith('@'));
  const people=chats||tab==='people'||Boolean(peer)||term.startsWith('@');
  const section=chats?'chats':people?'people':tab==='groups'?'groups':'rooms';
  const communities=tab==='groups';
  const members:{id:string;display_name:string}[]=[];
  async function loadMembers(){
    if(!people)return [];
    if(chats){
      const contacts=(await contactList()).filter(person=>person.status==='accepted');
      if(!contacts.length)return [];
      const profiles=rows(await storageAdmin().from('profiles').select('id,display_name').in('id',contacts.map(person=>person.peer)).order('display_name').order('id'));
      return profiles.filter(person=>matchesMember(person.id,person.display_name,term)).slice(offset,offset+pageSize+1);
    }
    if(!term || term==='@')return rows(await client.from('profiles').select('id,display_name').neq('id',user.id).order('id').range(offset,offset+pageSize));
    // A signed-in name search exposes only public chat identity fields.
    const directory=storageAdmin();
    for(let start=0;members.length<=offset+pageSize;start+=250){
      const batch=rows(await directory.from('profiles').select('id,display_name').neq('id',user.id).order('id').range(start,start+249));
      members.push(...batch.filter(person=>matchesMember(person.id,person.display_name,term)));
      if(batch.length<250)break;
    }
    return members.slice(offset,offset+pageSize+1);
  }
  let query=client.from('issues').select('id,title,status,updated_at,room_context(body,sent_at)').order('sent_at',{referencedTable:'room_context',ascending:false}).limit(1,{referencedTable:'room_context'}).order('updated_at',{ascending:false}).order('id');
  if(term)query=query.ilike('title','%'+term.replace(/[\\%_]/g,'\\$&')+'%');
  async function loadRooms(){
    if(people)return [];
    if(!communities)return rows(await query.range(offset,offset+pageSize));
    let groups=client.from('workspaces').select('id,name,workspace_members!inner(role,user_id)').eq('workspace_members.user_id',user.id).neq('workspace_members.role','guest').order('name').order('id');
    if(term)groups=groups.ilike('name','%'+term.replace(/[\\%_]/g,'\\$&')+'%');
    return rows(await groups.range(offset,offset+pageSize)).map(group=>({id:group.id,title:group.name,status:'Group chat',updated_at:null,room_context:[]}));
  }
  const [directory,rooms,active,person,profile]=await Promise.all([
    loadMembers(),
    loadRooms(),
    room?client.from('issues').select('id,title,workspace_id,status,priority').eq('id',room).maybeSingle():null,
    peer?storageAdmin().from('profiles').select('id,display_name').eq('id',peer).maybeSingle():null,
    client.from('profiles').select('display_name').eq('id',user.id).maybeSingle()
  ]);
  if(active?.error)throw new Error('Could not load this conversation.');
  if(room&&!active?.data)notFound();
  if(peer&&(!person?.data||peer===user.id))notFound();
  const current=1+offset/pageSize;
  const link=(page:number,id?:string)=>'/communication?'+new URLSearchParams({tab:section,q:term,page:String(page),...(id?{[people?'peer':'room']:id}:{})});
  const title=person?.data?.display_name||active?.data?.title;
  const own=profile.data;
  const linked = room && active?.data ? rows(await client.from('issues').select('id,title,status').eq('workspace_id',active.data.workspace_id).like('description','%Source message: /issues/'+room+'#message-%').order('updated_at',{ascending:false}).limit(30)) : [];
  const membership=active?.data ? await client.from('workspace_members').select('role').eq('workspace_id',active.data.workspace_id).eq('user_id',user.id).maybeSingle() : null;
  const roster=active?.data && membership?.data && membership.data.role!=='guest' ? rows(await client.from('workspace_members').select('user_id,profiles(display_name)').eq('workspace_id',active.data.workspace_id).limit(100)) : [];
  const memberNames=Object.fromEntries(roster.map(m=>['u'+m.user_id.replaceAll('-',''),(Array.isArray(m.profiles)?m.profiles[0]:m.profiles)?.display_name||'Member']));
  const canCreate=membership?.data && membership.data.role!=='guest';

  return <div className="messenger communication-v4"><header className="inbox-title"><details className="mobile-inbox-nav"><summary aria-label="Open workspace navigation">Menu</summary><WorkspaceNav/></details><div><h1>Communication</h1><p>Conversations and issue rooms</p></div><Link className="btn btn-primary" href="/communication?tab=people#directory-search"><SquarePen size={17}/> New message</Link></header>
    <div className="conversation-hub" data-open={Boolean(peer||room||tab==='ai')}>
      <aside className="panel stack inbox-directory"><h2>Inbox</h2><nav className="inbox-tabs" aria-label="Inbox sections"><Link href="/communication?tab=chats" aria-current={chats?'page':undefined}>Direct</Link><Link href="/communication?tab=groups" aria-current={communities?'page':undefined}>Groups</Link><Link prefetch={true} aria-current={section==='rooms'?'page':undefined} href="/communication?tab=rooms"><Hash size={16}/> Rooms</Link><Link prefetch={true} aria-current={people&&!chats?'page':undefined} href="/communication?tab=people"><AtSign size={16}/> People</Link></nav>
      <form action="/communication" className="inbox-search"><input type="hidden" name="tab" value={section}/><input key={term} id="directory-search" type="search" aria-label="Search rooms or @username" name="q" defaultValue={term} placeholder={people?'Name or @username':communities?'Community name':'Room or @username'}/><button aria-label="Search"><SearchIcon size={17}/></button></form>
      <ContactRequests/><nav aria-label="Conversations" className="conversation-list">{people?directory.slice(0,pageSize).map(m=><Link className="inbox-row" aria-current={peer===m.id?'page':undefined} href={link(current,m.id)} key={m.id}><b>{m.display_name.slice(0,1)}</b><span>{m.display_name}<small>{memberHandle(m.id,m.display_name)}</small></span></Link>):rooms.slice(0,pageSize).map(r=><Link className="inbox-row" aria-current={room===r.id?'page':undefined} href={communities?'/communities/'+r.id:link(current,r.id)} key={r.id}><b>#</b><span>{r.title}<small className="room-snippet">{r.room_context?.[0]?.body || r.status.replaceAll('_',' ').toLowerCase()}{r.updated_at && <> · <time dateTime={r.updated_at}>{new Date(r.updated_at).toLocaleDateString('en',{month:'short',day:'numeric',timeZone:'UTC'})}</time></>}</small></span></Link>)}</nav>
      {(people?!directory.length:!rooms.length)&&<p>{people&&term&&matchesMember(user.id,own?.display_name||'Member',term)?'Your profile matches. No other people matched this search.':term?'No matches. Try another search.':chats?'Approved conversations appear here. Find someone in People to start a chat.':people?'Teammates appear here when you share a workspace.':communities?'Your communities appear here.':'Your workspace issue rooms appear here.'}</p>}
      {current>1&&<Link href={link(current-1)}>Previous</Link>}{(people?directory.length:rooms.length)>pageSize&&<Link href={link(current+1)}>More results</Link>}
      <Link className="assistant-link" href="/communication?tab=ai">✦ Apex AI <span>Ask a question →</span></Link><footer className="directory-self"><strong>{own?.display_name||'Your profile'}</strong><small>{memberHandle(user.id,own?.display_name||"Member")}</small></footer></aside>
      <section className="hub-thread panel stack">{tab==='ai'?<><Link href="/communication">Back to inbox</Link><ApexAssistant/></>:title?<><header className="thread-identity"><Link aria-label="Back to inbox" href={link(current)}><ArrowLeft size={19}/></Link><b aria-hidden="true">{person?.data?title.slice(0,1):'#'}</b><div><h2>{title}</h2>{person?.data&&<small>{memberHandle(person.data.id,person.data.display_name)}</small>}</div>{room&&<Link className="thread-issue" href={'/issues/'+room}>Issue details <ArrowUpRight size={16}/></Link>}</header>{peer?<ContactGate peer={peer} notice={notice}/>:<RoomTranscriptProvider key={room}><RoomChat issueId={room!} memberNames={memberNames} workspace={canCreate?active?.data?.workspace_id:undefined}/>{canCreate&&process.env.AI_ENABLED==='true'&&<details className="thread-analysis"><summary>AI summary and action items</summary><Analysis issue={room!} enabled fallback={false} primary="openrouter"/></details>}</RoomTranscriptProvider>}</>:<div className="inbox-welcome"><div aria-hidden="true" className="inbox-art"><MessagesSquare size={54}/><AtSign size={28}/></div><h2>Start a conversation</h2><p>Find someone by name or username, or open a group chat.</p>{people&&!chats&&!term?<a className="btn btn-primary" href="#directory-search">Search people</a>:<Link className="btn btn-primary" href="/communication?tab=people#directory-search">Browse people</Link>}<Link href="/communities/new">Create a community</Link></div>}</section>
      {active?.data && <aside className="room-context"><details open><summary>Room details</summary><dl><dt>Status</dt><dd>{active.data.status.toLowerCase().replaceAll('_',' ')}</dd><dt>Priority</dt><dd>{active.data.priority}</dd></dl><Link href={'/issues/'+room+'#tasks'}>Tasks and evidence →</Link><h3>Issues from this conversation</h3>{linked.length?<ul>{linked.map(i=><li key={i.id}><Link href={'/issues/'+i.id}>{i.title}</Link><small>{i.status.toLowerCase().replaceAll('_',' ')}</small></li>)}</ul>:<p>No messages have been converted to issues yet.</p>}</details></aside>}
    </div></div>;
}
