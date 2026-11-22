import {redirect} from 'next/navigation';
import Link from 'next/link';
import WorkspaceIssueDestination from '@/components/WorkspaceIssueDestination';
import {homeMode} from '@/lib/modes';
import {session,rows} from '@/lib/db';
import {Feedback,Form,Button,Status,statuses,human,type Query} from '@/components/WorkspaceUI';
import {
  AlertTriangle,ArrowUpRight,BadgeCheck,CheckCircle2,ClipboardList,Clock3,Compass,Flame,
  Inbox,MessagesSquare,Plus,ShieldAlert,Sparkles,Users,Zap
} from 'lucide-react';

type AlertItem={id:string;title:string;kind:'review'|'legacy'|'critical'|'request'|'task';detail:string;href:string};

export default async function Dashboard({searchParams}:{searchParams:Promise<Query>}){
  const {client,user}=await session();
  const q=await searchParams;
  const preference=homeMode(user.user_metadata.home_mode);
  const mode=q.view==='resolution'||q.view==='explore'?q.view:preference;
  if(mode==='communication'&&q.create!=='workspace')redirect('/communication');

  const workspaces=rows(await client.from('workspaces').select('id,name').order('name'));
  const scope=workspaces.find(w=>w.id===q.workspace);
  const status=statuses.find(s=>s===q.status);
  const search=q.q?.trim().slice(0,100)||'';
  let queue=client.from('issues').select('id,title,status,priority,updated_at,legacy_review_required').order('updated_at',{ascending:false}).order('id');
  if(scope)queue=queue.eq('workspace_id',scope.id);
  if(status)queue=queue.eq('status',status);
  if(status==='VERIFIED_RESOLVED')queue=queue.eq('legacy_review_required',false);
  if(search)queue=queue.ilike('title','%'+search.replace(/[\\%_]/g,'\\$&')+'%');

  const [issues,activity,assigned,...rest]=await Promise.all([
    queue.limit(mode==='resolution'?50:8),
    client.from('audit_events').select('id,issue_id,action,created_at').order('created_at',{ascending:false}).limit(8),
    client.from('tasks').select('id,title,status,issue_id').eq('assignee_id',user.id).order('created_at',{ascending:false}).limit(8),
    ...['ALL',...statuses].map(s=>{
      let count=client.from('issues').select('id',{count:'exact',head:true});
      if(scope)count=count.eq('workspace_id',scope.id);
      if(s==='VERIFIED_RESOLVED')count=count.eq('legacy_review_required',false);
      return s==='ALL'?count:count.eq('status',s);
    }),
    client.from('issues').select('id,title,status,priority,legacy_review_required,updated_at').or('status.eq.PENDING_VERIFICATION,legacy_review_required.eq.true,priority.eq.critical').order('updated_at',{ascending:false}).limit(6),
    client.from('contact_requests').select('id',{count:'exact',head:true}).eq('recipient',user.id).eq('status','pending'),
    client.from('profiles').select('display_name').eq('id',user.id).maybeSingle()
  ]);
  const counts=rest.slice(0,5) as {count:number|null}[];
  const attentionResult=rest[5] as {data:unknown[]|null;error:unknown};
  const requestResult=rest[6] as {count:number|null;error:unknown};
  const profileResult=rest[7] as {data:{display_name:string}|null;error:unknown};
  if(counts.some(c=>!c))throw new Error('Issue counts unavailable.');
  const recent=rows(issues),tasks=rows(assigned),events=rows(activity);
  const attention=rows(attentionResult as {data:{id:string;title:string;status:string;priority:string;legacy_review_required:boolean;updated_at:string}[]|null;error:unknown});
  const pendingRequests=requestResult.count??0;
  const displayName=profileResult.data?.display_name||'teammate';
  const isQueue=mode==='resolution';
  const alerts:AlertItem[]=[
    ...attention.map(item=>{
      if(item.legacy_review_required)return {id:item.id,title:item.title,kind:'legacy' as const,detail:'Historical approval needs an independent review.',href:'/issues/'+item.id};
      if(item.status==='PENDING_VERIFICATION')return {id:item.id,title:item.title,kind:'review' as const,detail:'Evidence is waiting for an independent verifier.',href:'/issues/'+item.id+'#review'};
      return {id:item.id,title:item.title,kind:'critical' as const,detail:item.priority+' priority needs a resolver.',href:'/issues/'+item.id};
    }),
    ...(pendingRequests?[{id:'requests',title:pendingRequests+' chat request'+(pendingRequests===1?'':'s'),kind:'request' as const,detail:'Someone wants to start a private conversation.',href:'/communication?tab=people'}]:[]),
    ...(tasks.length?[{id:'tasks',title:tasks.length+' task'+(tasks.length===1?'':'s')+' assigned',kind:'task' as const,detail:'Your queue has work you own.',href:'#assigned'}]:[])
  ].slice(0,6);
  const openCount=counts[1]?.count??0;
  const progressCount=counts[2]?.count??0;
  const reviewCount=counts[3]?.count??0;
  const verifiedCount=counts[4]?.count??0;

  return <div className="stack explorer-v2">
    <header className="page-header explorer-head">
      <div><p className="eyebrow"><span className="signal-line"/>{isQueue?'Resolution':'Explorer'}</p><h1>{isQueue?'Resolution command center':'Good to see you, '+displayName.split(' ')[0]+'.'}</h1><p>{isQueue?'Everything waiting on evidence, review or a resolver.':'Your workspace at a glance — alerts first, noise last.'}</p></div>
    </header>
    <Feedback q={q}/>

    {isQueue?<>
      <section className="explorer-hero queue-hero">
        <div className="explorer-hero-copy"><span className="explorer-kicker"><Flame size={14}/> Resolution queue</span><h2>{reviewCount?reviewCount+' item'+(reviewCount===1?'':'s')+' need independent review':'Nothing is blocked on review.'}</h2><p>Open issues, evidence and approvals in one place. The reviewer cannot be the person who fixed it.</p><div className="explorer-hero-actions"><a className="btn btn-primary" href={"?"+new URLSearchParams({...Object.fromEntries(Object.entries(q).filter((entry): entry is [string,string]=>typeof entry[1]==='string')),view:'resolution',create:'issue'})+"#new-issue"}><Plus size={17}/> Create issue</a><Link className="btn" href="/communication?tab=rooms"><MessagesSquare size={17}/> Open rooms</Link></div></div>
        <div className="explorer-stat-grid"><div><small>Open</small><strong>{openCount}</strong></div><div><small>In progress</small><strong>{progressCount}</strong></div><div><small>Review</small><strong>{reviewCount}</strong></div><div><small>Verified</small><strong>{verifiedCount}</strong></div></div>
      </section>
      <section className="panel stack queue-panel"><header className="queue-title"><h2>Queue</h2><span className="explorer-count">{recent.length} shown</span></header>
        <form action="/dashboard" className="queue-filter"><input type="hidden" name="view" value="resolution"/>
          <label>Workspace<select name="workspace" defaultValue={scope?.id||''}><option value="">All my workspaces</option>{workspaces.map(w=><option key={w.id} value={w.id}>{w.name}</option>)}</select></label>
          <label>Find issue<input name="q" type="search" defaultValue={search} maxLength={100}/></label>
          <label>Status<select name="status" defaultValue={status||''}><option value="">All statuses</option>{statuses.map(s=><option key={s} value={s}>{human(s)}</option>)}</select></label><Button>Filter issues</Button>
        </form>
        <dl className="queue-counts">{['Total',...statuses.map(human)].map((label,i)=><div key={label}><dt>{label}</dt><dd>{counts[i]?.count??0}</dd></div>)}</dl>
        {recent.length?<div className="queue-scroll"><table className="issue-queue"><caption>Most recently updated issues · up to 50</caption><thead><tr><th>Issue</th><th>Status</th><th>Priority</th><th>Updated</th></tr></thead><tbody>{recent.map(i=><tr key={i.id}><td><Link href={'/issues/'+i.id}>{i.title}</Link></td><td>{i.legacy_review_required?<span className="badge">Independent review needed</span>:<Status s={i.status}/>}</td><td>{human(i.priority)}</td><td><time dateTime={i.updated_at}>{new Date(i.updated_at).toLocaleDateString('en',{timeZone:'UTC'})}</time></td></tr>)}</tbody></table></div>:<p>No issues match this queue.</p>}
        <details id="new-issue" open={q.create==='issue'}><summary>Create an issue</summary>{workspaces.length?<Form op="issue" fields={{id:crypto.randomUUID(),priority:'medium'}}><WorkspaceIssueDestination workspaces={workspaces} initial={scope?.id||workspaces[0].id}/><label>Issue title<input name="title" required maxLength={180}/></label><label>Description<textarea name="description" required maxLength={3000}/></label><Button>Create issue</Button></Form>:<a href="#create">Create a workspace</a>}</details>
      </section>
    </>:<>
      <section className="explorer-hero">
        <div className="explorer-hero-copy"><span className="explorer-kicker"><Sparkles size={14}/> Live workspace</span><h2>{alerts.length?alerts.length+(alerts.length===1?' thing wants':' things want')+' your attention':'Everything is calm.'}</h2><p>Review what is stuck, jump into the conversation, or start the next resolution. No hunting through menus.</p><div className="explorer-hero-actions"><Link className="btn btn-primary" href="/communication?tab=chats"><MessagesSquare size={17}/> Open messages</Link><Link className="btn" href="/dashboard?view=resolution"><ClipboardList size={17}/> Resolution queue</Link><Link className="btn" href="/communities/new"><Users size={17}/> New community</Link></div></div>
        <div className="explorer-stat-grid"><div><small>Open</small><strong>{openCount}</strong><span>need a fix</span></div><div><small>In progress</small><strong>{progressCount}</strong><span>being worked</span></div><div><small>Review</small><strong>{reviewCount}</strong><span>waiting on proof</span></div><div><small>Verified</small><strong>{verifiedCount}</strong><span>closed with evidence</span></div></div>
      </section>

      <div className="explorer-columns">
        <section className="panel alert-panel"><header className="explorer-section-head"><div><span className="explorer-kicker"><AlertTriangle size={14}/> Needs attention</span><h2>Alerts, not noise</h2></div><Link href="/dashboard?view=resolution">See queue <ArrowUpRight size={15}/></Link></header>
          {alerts.length?<div className="alert-grid">{alerts.map(alert=>{
            const Icon=alert.kind==='review'?BadgeCheck:alert.kind==='legacy'?ShieldAlert:alert.kind==='critical'?Flame:alert.kind==='request'?Inbox:Zap;
            return <Link className="alert-card" data-kind={alert.kind} href={alert.href} key={alert.id}><span className="alert-icon"><Icon size={18}/></span><span><strong>{alert.title}</strong><small>{alert.detail}</small></span><ArrowUpRight size={15}/></Link>;
          })}</div>:<div className="alert-clear"><CheckCircle2 size={22}/><div><strong>You are all caught up.</strong><p>No reviews, requests or critical issues are waiting.</p></div></div>}
        </section>
        <section className="panel quick-panel"><header className="explorer-section-head"><div><span className="explorer-kicker"><Zap size={14}/> Quick actions</span><h2>Start something</h2></div></header><div className="quick-grid"><Link href="/communication?tab=people#directory-search"><MessagesSquare/><span><strong>New message</strong><small>Find a teammate</small></span></Link><Link href="/dashboard?view=resolution&create=issue"><Plus/><span><strong>New issue</strong><small>Track a problem</small></span></Link><Link href="/communities/new"><Users/><span><strong>New community</strong><small>Bring people together</small></span></Link><Link href="/communication?tab=ai"><Sparkles/><span><strong>Ask Apex AI</strong><small>Get a second look</small></span></Link></div></section>
      </div>

      <div className="explorer-columns">
        <section className="panel"><header className="explorer-section-head"><div><span className="explorer-kicker"><MessagesSquare size={14}/> Recent</span><h2>Conversations</h2></div><Link href="/communication?tab=rooms">All rooms <ArrowUpRight size={15}/></Link></header>{recent.length?<div className="recent-list">{recent.slice(0,5).map(i=><Link className="recent-row" key={i.id} href={'/communication?room='+i.id}><span className="recent-avatar">{i.title.slice(0,1).toUpperCase()}</span><span><strong>{i.title}</strong><small>{human(i.status)} · {human(i.priority)} priority</small></span><ArrowUpRight size={15}/></Link>)}</div>:<p className="muted">Your issue conversations appear here.</p>}</section>
        <section className="panel"><header className="explorer-section-head"><div><span className="explorer-kicker"><ClipboardList size={14}/> Work</span><h2>Open issues</h2></div><Link href="/dashboard?view=resolution">Queue <ArrowUpRight size={15}/></Link></header>{recent.filter(i=>i.status!=='VERIFIED_RESOLVED').length?<div className="recent-list">{recent.filter(i=>i.status!=='VERIFIED_RESOLVED').slice(0,5).map(i=><Link className="recent-row" key={i.id} href={'/issues/'+i.id}><span className="recent-avatar status-dot" data-status={i.status}/><span><strong>{i.title}</strong><small>{human(i.status)} · {human(i.priority)}</small></span><ArrowUpRight size={15}/></Link>)}</div>:<p className="muted">No open issues. Nice.</p>}</section>
      </div>

      <div className="explorer-columns">
        <section className="panel" id="assigned"><header className="explorer-section-head"><div><span className="explorer-kicker"><Clock3 size={14}/> Yours</span><h2>Assigned to you</h2></div></header>{tasks.length?<div className="recent-list">{tasks.map(t=><Link className="recent-row" key={t.id} href={'/issues/'+t.issue_id+'#tasks'}><span className="recent-avatar task-dot"/><span><strong>{t.title}</strong><small>{human(t.status)}</small></span><ArrowUpRight size={15}/></Link>)}</div>:<p className="muted">No assigned tasks.</p>}</section>
        <section className="panel"><header className="explorer-section-head"><div><span className="explorer-kicker"><Compass size={14}/> Activity</span><h2>What changed</h2></div></header>{events.length?<ol className="activity explorer-activity">{events.map(a=><li key={a.id}><Link href={'/issues/'+a.issue_id}>{human(a.action)}</Link><time>{new Date(a.created_at).toLocaleString('en',{month:'short',day:'numeric',hour:'numeric',minute:'2-digit'})}</time></li>)}</ol>:<p>Activity appears when someone updates a room.</p>}</section>
      </div>

      <section className="panel explorer-workspaces" id="workspaces"><header className="explorer-section-head"><div><span className="explorer-kicker"><Users size={14}/> Spaces</span><h2>Your workspaces</h2></div><Link href="/communication?tab=groups">Browse groups <ArrowUpRight size={15}/></Link></header><div className="workspace-chip-row">{workspaces.map(w=><Link key={w.id} href={'/workspaces/'+w.id}><span>{w.name.slice(0,1).toUpperCase()}</span>{w.name}</Link>)}{!workspaces.length&&<p className="muted">No workspaces yet.</p>}</div></section>
    </>}

    {isQueue&&<section className="panel"><h2>Recent activity</h2><ul className="activity">{events.map(a=><li key={a.id}><Link href={'/issues/'+a.issue_id}>{human(a.action)}</Link><time>{new Date(a.created_at).toUTCString()}</time></li>)}</ul>{!events.length&&<p>Activity appears when someone updates a room.</p>}</section>}
    <details className="panel" id="create"><summary>Create workspace</summary><Form op="workspace"><label>Workspace name<input required name="title" maxLength={100}/></label><label>Description<textarea name="description"/></label><Button>Create workspace</Button></Form></details>
  </div>;
}
