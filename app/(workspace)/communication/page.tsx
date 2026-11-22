import {contactList} from '@/lib/contact-list';
import {ContactGate,ContactRequests} from '@/components/ContactGate';
import {AtSign,BadgeCheck,Flame,Hash,Inbox,LockKeyhole,Menu,MessagesSquare,Plus,Search as SearchIcon,ShieldCheck,Sparkles,SquarePen,ArrowLeft,ArrowUpRight,Users} from 'lucide-react';
import {matchesMember,memberHandle} from '@/lib/handles';
import WorkspaceNav from '@/components/WorkspaceNav';
import ApexAssistant from '@/components/ApexAssistant';
import Link from 'next/link';
import {notFound} from 'next/navigation';
import RoomChat from '@/components/RoomChat';
import {RoomTranscriptProvider} from '@/components/RoomTranscript';
import ChatInfoToggle, {ChatShell} from '@/components/ChatInfoToggle';
import {rows,session,storageAdmin} from '@/lib/db';

type Search = {contact?:string;room?:string;peer?:string;tab?:string;q?:string;notice?:string;page?:string};
const pageSize=25;

function avatarStyle(id:string){
  let hue=0;
  for(let i=0;i<id.length;i++)hue=(hue*31+id.charCodeAt(i))%360;
  return {background:`linear-gradient(140deg,hsl(${hue} 58% 34%),hsl(${(hue+42)%360} 62% 21%))`};
}
function shortTime(value?:string|null){
  if(!value)return '';
  const date=new Date(value),now=new Date();
  if(date.toDateString()===now.toDateString())return date.toLocaleTimeString('en',{hour:'numeric',minute:'2-digit',timeZone:'UTC'});
  return date.toLocaleDateString('en',{month:'short',day:'numeric',timeZone:'UTC'});
}
function isHot(updatedAt:string|null|undefined){
  if(!updatedAt)return false;
  return Date.now()-new Date(updatedAt).getTime()<86400000;
}

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
  const people=chats||tab==='people'||Boolean(peer)||(tab!=='groups'&&term.startsWith('@'));
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
    let groups=client.from('workspaces').select('id,name,workspace_members!inner(role,user_id)').eq('workspace_members.user_id',user.id).neq('workspace_members.role','guest').eq('community_state','active').order('name').order('id');
    if(term)groups=groups.ilike('name','%'+term.replace(/[\\%_]/g,'\\$&')+'%');
    return rows(await groups.range(offset,offset+pageSize)).map(group=>({id:group.id,title:group.name,status:'Group chat',updated_at:null,room_context:[]}));
  }
  const [directory,rooms,active,person,profile,pulse]=await Promise.all([
    loadMembers(),
    loadRooms(),
    room?client.from('issues').select('id,title,workspace_id,status,priority').eq('id',room).maybeSingle():null,
    peer?storageAdmin().from('profiles').select('id,display_name').eq('id',peer).maybeSingle():null,
    client.from('profiles').select('display_name').eq('id',user.id).maybeSingle(),
    client.from('issues').select('id,title,status,updated_at').order('updated_at',{ascending:false}).limit(8)
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
  const list=(people?directory.slice(0,pageSize).map(item=>({
    id:item.id,name:item.display_name,
    subtitle:chats?'Private conversation · tap to open':memberHandle(item.id,item.display_name),
    updated_at:null as string|null,badge:'',href:link(current,item.id),person:true,hot:false
  })):rooms.slice(0,pageSize).map(item=>({
    id:item.id,name:item.title,
    subtitle:communities?'Community · group chat':(item.room_context?.[0]?.body||item.status.replaceAll('_',' ').toLowerCase()),
    updated_at:item.updated_at as string|null,
    badge:!communities&&item.status==='PENDING_VERIFICATION'?'Review':!communities&&item.status==='OPEN'?'Open':'',
    href:communities?'/communities/'+item.id:link(current,item.id),person:false,
    hot:!communities&&item.status!=='VERIFIED_RESOLVED'&&isHot(item.updated_at)
  })));
  const pulseRooms=rows(pulse).slice(0,7);
  const ownInitial=(own?.display_name||user.email||'A').slice(0,1).toUpperCase();
  const threadSubtitle=person?.data?memberHandle(person.data.id,person.data.display_name):active?.data?`${active.data.status.toLowerCase().replaceAll('_',' ')} · ${active.data.priority} priority`:'';
  const hasThread=Boolean(title||tab==='ai');

  return <div className="messenger wa-app">
    <ChatShell key={room||peer||tab} thread={hasThread} info={active?.data?'room':person?.data?'person':'none'}>
      <aside className="wa-list" aria-label="Chat list">
        <header className="wa-list-head">
          <details className="wa-mobile-nav"><summary aria-label="Open workspace navigation"><Menu size={19}/></summary><WorkspaceNav/></details>
          <span className="wa-own-avatar" aria-hidden="true">{ownInitial}</span>
          <div className="wa-list-title"><h1>Chats</h1><small>{people?'People and private messages':communities?'Communities':'Resolution rooms'}</small></div>
          <div className="wa-list-actions">
            <Link href="/communication?tab=ai" className="wa-icon-btn" aria-label="Ask Apex AI" title="Ask Apex AI"><Sparkles size={18}/></Link>
            <Link href="/communication?tab=people#directory-search" className="wa-icon-btn" aria-label="New chat" title="New chat"><SquarePen size={18}/></Link>
          </div>
        </header>
        <form action="/communication" className="wa-search" role="search">
          <input type="hidden" name="tab" value={section}/>
          <SearchIcon size={17} aria-hidden="true"/>
          <input key={term} id="directory-search" type="search" aria-label="Search rooms or @username" name="q" defaultValue={term} placeholder={people?'Search people or @username':communities?'Search communities':'Search rooms or @username'}/>
          <button type="submit" aria-label="Search"><SearchIcon size={16}/></button>
        </form>
        <nav className="wa-filters" aria-label="Inbox sections">
          <Link href="/communication?tab=chats" aria-current={chats?'page':undefined}><MessagesSquare size={15}/> Chats</Link>
          <Link href="/communication?tab=groups" aria-current={communities?'page':undefined}><Users size={15}/> Groups</Link>
          <Link href="/communication?tab=rooms" aria-current={section==='rooms'?'page':undefined}><Hash size={15}/> Rooms</Link>
          <Link href="/communication?tab=people" aria-current={people&&!chats?'page':undefined}><AtSign size={15}/> People</Link>
        </nav>
        <nav className="wa-pulse" aria-label="Workspace pulse">
          <Link href="/communication?tab=people#directory-search" className="wa-pulse-item"><span className="wa-ring wa-ring-new"><span className="wa-avatar"><Plus size={18}/></span></span><small>New</small></Link>
          {pulseRooms.map(item=><Link href={'/communication?tab=rooms&room='+item.id} className="wa-pulse-item" key={item.id}><span className="wa-ring" data-state={item.status}><span className="wa-avatar">#</span></span><small>{item.title}</small></Link>)}
        </nav>
        <div className="wa-list-scroll">
          {people&&<ContactRequests/>}
          <nav aria-label="Conversations" className="wa-chat-list">
            {list.map(item=>{
              const selected=item.person?peer===item.id:room===item.id;
              return <Link className="wa-chat-row" aria-current={selected?'page':undefined} href={item.href} key={item.id}>
                <span className={`wa-ring${item.hot?' is-hot':''}`} data-state={item.person?'person':undefined} aria-hidden="true"><span className="wa-avatar" style={item.person||communities?avatarStyle(item.id):undefined}>{item.person||communities?item.name.slice(0,1).toUpperCase():'#'}</span></span>
                <span className="wa-chat-main">
                  <span className="wa-chat-top"><strong>{item.name}</strong>{item.updated_at&&<time dateTime={item.updated_at}>{shortTime(item.updated_at)}</time>}</span>
                  <span className="wa-chat-bottom"><span className="wa-preview">{item.subtitle}</span>{item.badge&&<span className="wa-badge">{item.badge}</span>}{item.hot&&!item.badge&&<span className="wa-hot"><Flame size={11}/> Hot</span>}</span>
                </span>
              </Link>;
            })}
          </nav>
          {(people?!directory.length:!rooms.length)&&<div className="wa-list-empty"><Inbox size={22}/><p>{people&&term&&matchesMember(user.id,own?.display_name||'Member',term)?'Your profile matches. No other people matched this search.':term?'No matches. Try another search.':chats?'Approved conversations appear here. Find someone in People to start a chat.':people?'Teammates appear here when you share a workspace.':communities?'Your communities appear here.':'Your workspace issue rooms appear here.'}</p>{!term&&<Link href="/communication?tab=people#directory-search">Find someone</Link>}</div>}
          <div className="wa-pagination">{current>1&&<Link href={link(current-1)}>Previous</Link>}{(people?directory.length:rooms.length)>pageSize&&<Link href={link(current+1)}>More results</Link>}</div>
        </div>
        <footer className="wa-list-foot">
          <Link className="wa-assistant" href="/communication?tab=ai"><span><Sparkles size={16}/></span><div><strong>Apex AI</strong><small>Ask about this workspace</small></div><ArrowUpRight size={15}/></Link>
          <div className="wa-self"><span className="wa-avatar" style={avatarStyle(user.id)}>{ownInitial}</span><div><strong>{own?.display_name||'Your profile'}</strong><small>{memberHandle(user.id,own?.display_name||'Member')}</small></div><Link href="/settings" aria-label="Open settings"><ShieldCheck size={16}/></Link></div>
        </footer>
      </aside>

      <section className="wa-thread" aria-label="Conversation">
        {tab==='ai'?<>
          <header className="wa-thread-head"><Link className="wa-back" href={link(current)} aria-label="Back to chats"><ArrowLeft size={20}/></Link><span className="wa-avatar wa-ai-avatar" aria-hidden="true"><Sparkles size={19}/></span><div className="wa-thread-id"><h2>Apex AI</h2><small>Workspace assistant · advisory only</small></div></header>
          <div className="wa-thread-body wa-ai-body"><ApexAssistant/></div>
        </>:title?<>
          <header className="wa-thread-head">
            <Link className="wa-back" href={link(current)} aria-label="Back to chats"><ArrowLeft size={20}/></Link>
            <span className="wa-avatar" style={person?.data?avatarStyle(person.data.id):undefined} aria-hidden="true">{person?.data?title!.slice(0,1).toUpperCase():'#'}</span>
            <div className="wa-thread-id"><h2>{title}</h2><small>{threadSubtitle}</small></div>
            <div className="wa-thread-actions">
              {active?.data&&active.data.status!=='VERIFIED_RESOLVED'&&<span className="wa-heat"><Flame size={13}/> Active</span>}
              {room&&<Link className="wa-icon-btn" href={'/issues/'+room} title="Open issue details"><ArrowUpRight size={18}/><span className="sr-only">Issue details</span></Link>}
              <ChatInfoToggle hasInfo={Boolean(active?.data||person?.data)}/>
            </div>
          </header>
          <div className="wa-thread-body">
            {peer?<ContactGate peer={peer} notice={notice}/>:<RoomTranscriptProvider key={room}><RoomChat issueId={room!} memberNames={memberNames} workspace={canCreate?active?.data?.workspace_id:undefined}/></RoomTranscriptProvider>}
          </div>
        </>:<div className="wa-empty">
          <div className="wa-empty-art" aria-hidden="true"><MessagesSquare size={54}/><span><ShieldCheck size={20}/></span></div>
          <h2>Apex Resolve for teams</h2>
          <p>Choose a chat, group or resolution room. Every conversation can become tracked work with proof at the end.</p>
          <ul><li><LockKeyhole size={15}/> Private contact consent</li><li><BadgeCheck size={15}/> Independent verification</li><li><MessagesSquare size={15}/> One thread from report to fix</li></ul>
          <div className="wa-empty-actions"><Link className="btn btn-primary" href="/communication?tab=people#directory-search"><SquarePen size={17}/> New message</Link><Link className="btn" href="/communities/new"><Users size={17}/> Create community</Link></div>
          <small className="wa-empty-lock"><LockKeyhole size={13}/> Your workspace keeps evidence and reviews permission-aware.</small>
        </div>}
      </section>

      {active?.data&&<aside className="wa-info" id="chat-info" aria-label="Chat details">
        <header><h2>Room details</h2><ChatInfoToggle hasInfo close /></header>
        <div className="wa-info-profile"><span className="wa-avatar" aria-hidden="true">#</span><h3>{active.data.title}</h3><small>{active.data.status.toLowerCase().replaceAll('_',' ')} · {active.data.priority} priority</small></div>
        <div className="wa-info-actions"><Link href={'/issues/'+room}><ArrowUpRight size={16}/> Open resolution room</Link><Link href={'/issues/'+room+'#tasks'}><BadgeCheck size={16}/> Tasks and evidence</Link></div>
        <section className="wa-info-section"><h3>Members</h3>{roster.length?<ul className="wa-member-list">{roster.slice(0,12).map(m=>{const person=(Array.isArray(m.profiles)?m.profiles[0]:m.profiles)?.display_name||'Member';return <li key={m.user_id}><span className="wa-avatar small" style={avatarStyle(m.user_id)}>{person.slice(0,1).toUpperCase()}</span><span>{person}</span></li>})}</ul>:<p>Member list is private for guests.</p>}</section>
        <section className="wa-info-section"><h3>Issues from this conversation</h3>{linked.length?<ul className="wa-linked">{linked.map(i=><li key={i.id}><Link href={'/issues/'+i.id}>{i.title}</Link><small>{i.status.toLowerCase().replaceAll('_',' ')}</small></li>)}</ul>:<p>No messages have been converted to issues yet.</p>}</section>
        <p className="wa-info-note"><ShieldCheck size={14}/> Only workspace members can see this room and its evidence.</p>
      </aside>}
      {person?.data&&<aside className="wa-info" id="chat-info" aria-label="Contact details">
        <header><h2>Contact details</h2><ChatInfoToggle hasInfo close/></header>
        <div className="wa-info-profile"><span className="wa-avatar" style={avatarStyle(person.data.id)} aria-hidden="true">{title!.slice(0,1).toUpperCase()}</span><h3>{title}</h3><small>{memberHandle(person.data.id,person.data.display_name)}</small></div>
        <div className="wa-info-actions"><Link href={'/dashboard?view=resolution&create=issue'}><BadgeCheck size={16}/> Start a resolution issue</Link><Link href="/communication?tab=people#directory-search"><AtSign size={16}/> Find another person</Link></div>
        <section className="wa-info-section"><h3>Private chat</h3><p>Messages stay between accepted contacts. A contact PIN or an approved request opens this thread.</p></section>
        <p className="wa-info-note"><LockKeyhole size={14}/> Report anything that feels unsafe to a workspace admin.</p>
      </aside>}
    </ChatShell>
  </div>;
}
