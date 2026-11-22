import {redirect} from 'next/navigation';
import Link from 'next/link';
import WorkspaceIssueDestination from '@/components/WorkspaceIssueDestination';
import ModePicker from '@/components/ModePicker';
import {homeMode} from '@/lib/modes';
import {session,rows} from '@/lib/db';
import {Feedback,Form,Button,IssueList,Status,statuses,human,type Query} from '@/components/WorkspaceUI';

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

  const [issues,activity,assigned,...counts]=await Promise.all([
    queue.limit(mode==='resolution'?50:8),
    client.from('audit_events').select('id,issue_id,action,created_at').order('created_at',{ascending:false}).limit(8),
    client.from('tasks').select('id,title,status,issue_id').eq('assignee_id',user.id).order('created_at',{ascending:false}).limit(8),
    ...['ALL',...statuses].map(s=>{
      let count=client.from('issues').select('id',{count:'exact',head:true});
      if(scope)count=count.eq('workspace_id',scope.id);
      if(s==='VERIFIED_RESOLVED')count=count.eq('legacy_review_required',false);
      return s==='ALL'?count:count.eq('status',s);
    })
  ]);
  if(counts.some(c=>c.error))throw new Error('Issue counts unavailable.');
  const recent=rows(issues),tasks=rows(assigned),events=rows(activity);
  const isQueue=mode==='resolution';
  return <div className="stack"><header className="page-header"><h1>{isQueue?'Resolution command center':'Explorer'}</h1><ModePicker current={preference}/></header><Feedback q={q}/>
    {isQueue?<section className="panel stack"><header className="queue-title"><h2>Resolution queue</h2><a className="btn" href={"?"+new URLSearchParams({...Object.fromEntries(Object.entries(q).filter((entry): entry is [string,string]=>typeof entry[1]==='string')),view:'resolution',create:'issue'})+"#new-issue"}>Create issue</a></header>
      <form action="/dashboard" className="queue-filter"><input type="hidden" name="view" value="resolution"/>
        <label>Workspace<select name="workspace" defaultValue={scope?.id||''}><option value="">All my workspaces</option>{workspaces.map(w=><option key={w.id} value={w.id}>{w.name}</option>)}</select></label>
        <label>Find issue<input name="q" type="search" defaultValue={search} maxLength={100}/></label>
        <label>Status<select name="status" defaultValue={status||''}><option value="">All statuses</option>{statuses.map(s=><option key={s} value={s}>{human(s)}</option>)}</select></label><Button>Filter issues</Button>
      </form><dl className="queue-counts">{['Total',...statuses.map(human)].map((label,i)=><div key={label}><dt>{label}</dt><dd>{counts[i].count}</dd></div>)}</dl>
      {recent.length?<div className="queue-scroll"><table className="issue-queue"><caption>Most recently updated issues · up to 50</caption><thead><tr><th>Issue</th><th>Status</th><th>Priority</th><th>Updated</th></tr></thead><tbody>{recent.map(i=><tr key={i.id}><td><Link href={'/issues/'+i.id}>{i.title}</Link></td><td>{i.legacy_review_required?<span className="badge">Independent review needed</span>:<Status s={i.status}/>}</td><td>{human(i.priority)}</td><td><time dateTime={i.updated_at}>{new Date(i.updated_at).toLocaleDateString('en',{timeZone:'UTC'})}</time></td></tr>)}</tbody></table></div>:<p>No issues match this queue.</p>}
      <details id="new-issue" open={q.create==='issue'}><summary>Create an issue</summary>{workspaces.length?<Form op="issue" fields={{id:crypto.randomUUID(),priority:'medium'}}><WorkspaceIssueDestination workspaces={workspaces} initial={scope?.id||workspaces[0].id}/><label>Issue title<input name="title" required maxLength={180}/></label><label>Description<textarea name="description" required maxLength={3000}/></label><Button>Create issue</Button></Form>:<a href="#create">Create a workspace</a>}</details>
    </section>:<><section className="panel explorer-links" id="workspaces"><h2>Your workspaces</h2><div>{workspaces.map(w=><Link key={w.id} href={'/workspaces/'+w.id}>{w.name}</Link>)}</div><nav><Link href="/communication?tab=groups">Browse groups</Link><Link href="/communication?tab=chats">Direct messages</Link><Link href="/communication?tab=ai">Ask Apex AI</Link><Link href="/dashboard?view=resolution">Resolution queue</Link></nav></section><section className="panel"><h2>Recent conversations</h2>{recent.map(i=><p key={i.id}><Link href={'/communication?room='+i.id}>{i.title}</Link></p>)}{!recent.length&&<p>Your issue conversations appear here.</p>}</section><section className="panel"><h2>Open issues</h2><IssueList issues={recent.filter(i=>i.status!=='VERIFIED_RESOLVED')}/></section></>}
    <section className="panel"><h2>Assigned to you</h2>{tasks.map(t=><p key={t.id}><Link href={'/issues/'+t.issue_id+'#tasks'}>{t.title}</Link> · {human(t.status)}</p>)}{!tasks.length&&<p>No assigned tasks.</p>}</section>
    <section className="panel"><h2>Recent activity</h2><ul className="activity">{events.map(a=><li key={a.id}><Link href={'/issues/'+a.issue_id}>{human(a.action)}</Link><time>{new Date(a.created_at).toUTCString()}</time></li>)}</ul>{!events.length&&<p>Activity appears when someone updates a room.</p>}</section>
    <details className="panel" id="create"><summary>Create workspace</summary><Form op="workspace"><label>Workspace name<input required name="title" maxLength={100}/></label><label>Description<textarea name="description"/></label><Button>Create workspace</Button></Form></details></div>;
}
