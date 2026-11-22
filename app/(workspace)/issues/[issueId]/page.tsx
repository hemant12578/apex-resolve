import ProofGuard from '@/components/ProofGuard';
import {notFound} from 'next/navigation';
import Link from 'next/link';
import {session,rows} from '@/lib/db';
import {Form,Feedback,Button,Names,Status,human,type Query} from '@/components/WorkspaceUI';
import RoomChat from '@/components/RoomChat';
import Analysis from '@/components/Analysis';
import RoomPanels from '@/components/RoomPanels';
import ConfirmButton from '@/components/ConfirmButton';
import {RoomTranscriptProvider} from '@/components/RoomTranscript';
import {ArrowLeft,BadgeCheck,CheckCircle2,Clock3,ExternalLink,FileText,Flame,ListChecks,LockKeyhole,Paperclip,ShieldCheck,Sparkles,Users} from 'lucide-react';

const steps=['OPEN','IN_PROGRESS','PENDING_VERIFICATION','VERIFIED_RESOLVED'] as const;
const stepLabel={OPEN:'Reported',IN_PROGRESS:'In progress',PENDING_VERIFICATION:'Review',VERIFIED_RESOLVED:'Verified'} as const;

export default async function Room({params,searchParams}:{params:Promise<{issueId:string}>,searchParams:Promise<Query>}){
 const {issueId:id}=await params,{client,user}=await session();
 const {data:i}=await client.from('issues').select('*').eq('id',id).maybeSingle();if(!i)notFound();
 const [tasks,evidence,audit,m,memberList,reviews]=await Promise.all([
   client.from('tasks').select('*').eq('issue_id',id).order('created_at'),
   client.from('evidence').select('*').eq('issue_id',id).order('created_at',{ascending:false}).order('id',{ascending:false}),
   client.from('audit_events').select('*').eq('issue_id',id).order('created_at',{ascending:false}).limit(100),
   client.from('workspace_members').select('role').eq('workspace_id',i.workspace_id).eq('user_id',user.id).single(),
   client.from('workspace_members').select('user_id,role,profiles!inner(display_name)').eq('workspace_id',i.workspace_id),
   client.from('resolution_verifications').select('*').eq('issue_id',id).order('created_at',{ascending:false})]);
 if(!m.data)notFound();
 const role=m.data.role,team=role!=='guest',canVerify=['admin','verifier'].includes(role),editable=['OPEN','IN_PROGRESS'].includes(i.status);
 const people=rows(memberList).map(p=>({user_id:p.user_id,role:p.role,name:(Array.isArray(p.profiles)?p.profiles[0]:p.profiles)?.display_name||p.user_id}));
 const source=/\n\nSource message: ((?:\/issues\/|\/communities\/|\/communication\?contact=)[a-f0-9-]{36}#message-[A-Za-z0-9_%.-]+)$/.exec(i.description||'');
 const name=(id:string|null)=>people.find(p=>p.user_id===id)?.name||(id?id.slice(0,8):'Unassigned');
 const independent=canVerify && Boolean(i.verification_request_id&&i.verification_requested_by) && user.id!==i.assignee_id && user.id!==i.verification_requested_by && rows(evidence).some(e=>e.uploader_id!==user.id);
 const fields={issue:id},assignees=people.filter(p=>p.role!=='guest');
 const stepIndex=Math.max(0,steps.indexOf(i.status as typeof steps[number]));
 const taskFields=(t?:{title:string,description:string,status:string,assignee_id:string})=><><label>Title<input name="title" required maxLength={180} defaultValue={t?.title}/></label><label>Description<textarea name="description" maxLength={4000} defaultValue={t?.description}/></label><Names people={assignees} value={t?.assignee_id}/><label>Status<select name="status" defaultValue={t?.status||'TODO'}>{['TODO','IN_PROGRESS','DONE'].map(s=><option key={s} value={s}>{human(s)}</option>)}</select></label></>;
 return <div className="stack resolution-v2">
  <header className="resolution-head">
    <div className="resolution-head-main">
      <Link className="resolution-back" href={'/workspaces/'+i.workspace_id}><ArrowLeft size={16}/> Workspace</Link>
      <p className="eyebrow"><span className="signal-line"/>Resolution room</p>
      <h1>{i.title}</h1>
      <div className="resolution-meta"><Status s={i.status}/><span className="resolution-priority" data-priority={i.priority}><Flame size={13}/> {i.priority}</span><span><Users size={14}/> {people.length} members</span><span><Clock3 size={14}/> Updated {new Date(i.updated_at).toLocaleDateString('en',{month:'short',day:'numeric'})}</span></div>
    </div>
    <div className="resolution-head-side"><span className="resolution-lock"><LockKeyhole size={15}/> Evidence-aware room</span><Link className="btn" href={'/communication?room='+id}><Sparkles size={16}/> Open in messenger</Link></div>
  </header>
  <Feedback q={await searchParams}/>
  <ol className="resolution-steps" aria-label="Resolution progress">{steps.map((step,index)=><li key={step} data-state={index<stepIndex?'done':index===stepIndex?(i.status==='VERIFIED_RESOLVED'?'done':'current'):'next'}><span>{index<stepIndex||(index===stepIndex&&i.status==='VERIFIED_RESOLVED')?<CheckCircle2 size={16}/>:index+1}</span><div><strong>{stepLabel[step]}</strong><small>{index===0?'Problem captured':index===1?'Work and evidence':index===2?'Independent review':'Proof recorded'}</small></div></li>)}</ol>

  <RoomTranscriptProvider><RoomPanels>
   <div className="resolution-grid">
    <div className="stack resolution-left" id="details-panel">
      <section className="panel resolution-card"><header className="resolution-card-head"><span className="resolution-icon"><FileText size={17}/></span><div><h2>Issue details</h2><p>The report, the people and the source.</p></div></header><p className="resolution-description">{source?i.description.slice(0,source.index):i.description}</p>{source&&<Link className="resolution-source" href={source[1]}><ExternalLink size={15}/> Open source message</Link>}<dl className="resolution-facts"><div><dt>Priority</dt><dd>{human(i.priority)}</dd></div><div><dt>Affected</dt><dd>{i.affected_user_ids?.length?i.affected_user_ids.map(name).join(', '):'External or unknown'}</dd></div><div><dt>Resolver</dt><dd>{name(i.assignee_id)}</dd></div><div><dt>Filed by</dt><dd>{name(i.reporter_id)}</dd></div></dl></section>
      <section className="panel resolution-card stack" id="tasks"><header className="resolution-card-head"><span className="resolution-icon"><ListChecks size={17}/></span><div><h2>Tasks</h2><p>{rows(tasks).length?rows(tasks).length+' work item'+(rows(tasks).length===1?'':'s'):'Break the fix into steps.'}</p></div></header>{!rows(tasks).length&&<p className="muted">No tasks yet.</p>}{rows(tasks).map(t=><details key={t.id} className="resolution-task"><summary><span>{t.title}</span><small>{human(t.status)}</small></summary><p>{name(t.assignee_id)}</p>{team&&editable?<><Form op="task" fields={{...fields,id:t.id}}>{taskFields(t)}<Button>Save task</Button></Form><Form op="deleteTask" fields={{...fields,id:t.id}}><ConfirmButton prompt="Delete this task from the room?">Delete task</ConfirmButton></Form></>:<p>{t.description}</p>}</details>)}{team&&editable&&<details className="resolution-add"><summary>Add task</summary><Form op="task" fields={fields}>{taskFields()}<Button>Create task</Button></Form></details>}</section>
    </div>
    <section className="panel conversation resolution-chat" id="conversation"><RoomChat issueId={id} workspace={team?i.workspace_id:undefined}/></section>
    <div className="stack resolution-right" id="evidence-panel">
      <section className="panel resolution-card stack" id="evidence"><header className="resolution-card-head"><span className="resolution-icon"><Paperclip size={17}/></span><div><h2>Evidence</h2><p>Proof before a fix can be approved.</p></div><span className="resolution-count">{rows(evidence).length}</span></header>{!rows(evidence).length&&<p className="muted">Attach proof before requesting verification.</p>}{rows(evidence).map((e,index)=><article className="evidence-card" key={e.id}><header><span className="evidence-kind">{e.kind}</span><small>#{rows(evidence).length-index} · {name(e.uploader_id)}</small></header><p>{e.description}</p><footer><time>{new Date(e.created_at).toLocaleString('en',{month:'short',day:'numeric',hour:'numeric',minute:'2-digit'})}</time>{e.kind==='url'&&<a href={e.value} rel="noopener noreferrer" target="_blank">Open verification URL</a>}{e.kind==='file'&&<a href={'/api/evidence/'+e.id}>Download private file</a>}</footer></article>)}
      {editable&&(['note','url','file'] as const).map(kind=><details key={kind} className="resolution-add"><summary>Add {kind==='url'?'verification URL':kind}</summary><Form op="evidence" fields={{...fields,kind,id:crypto.randomUUID()}}><label>{kind==='note'?'Written evidence':'Description'}<textarea required name="description" maxLength={4000}/></label>{kind==='url'&&<label>HTTPS URL<input name="value" type="url" required/></label>}{kind==='file'&&<label>PNG, JPEG, PDF or text log · 4 MiB max<input name="file" type="file" required accept=".png,.jpg,.jpeg,.pdf,.txt,.log"/></label>}<Button>Attach evidence</Button></Form></details>)}</section>
      {team&&<ProofGuard issue={id}/>}
      <section className="panel resolution-card stack review-card" id="review"><header className="resolution-card-head"><span className="resolution-icon"><ShieldCheck size={17}/></span><div><h2>Human verification</h2><p>Someone independent checks the proof.</p></div></header>{i.verification_requested_by&&<p className="review-requested">Requested by {name(i.verification_requested_by)}</p>}{team&&editable&&<Form op="transition" fields={{...fields,action:i.status==='OPEN'?'start':'request'}}><Button>{i.status==='OPEN'?'Start work':'Request verification'}</Button></Form>}
      {i.status==='PENDING_VERIFICATION'&&(independent?<Form op="transition" fields={{...fields,reviewRequest:i.verification_request_id}}><label>Review notes<textarea name="notes" maxLength={4000}/></label><label>Knowledge tags<input name="tags" placeholder="checkout, payments"/></label><div className="review-actions"><button className="btn btn-primary" name="action" value="approve">Approve resolution</button><button className="btn" name="action" value="reject">Reject with reason</button></div></Form>:<div className="review-wait"><BadgeCheck size={22}/><div><p>Awaiting independent reviewer. Ask another workspace admin or verifier to inspect the evidence.</p>{i.verification_requested_by===user.id&&<Form op="transition" fields={{...fields,action:'withdraw',reviewRequest:i.verification_request_id}}><Button>Withdraw for revision</Button></Form>}</div></div>)}{i.legacy_review_required&&<p role="alert" className="error">Review required · Historical approval needs an independent review. Reopen to review again.</p>}{canVerify&&i.status==='VERIFIED_RESOLVED'&&<Form op="transition" fields={{...fields,action:'reopen'}}><label>Reason<textarea name="notes" required/></label><Button>Reopen issue</Button></Form>}{rows(reviews).map(r=><p key={r.id} className="review-record"><strong>{r.approved?'Approved':'Rejected'} by {name(r.verifier_id)}</strong><br/>{r.notes} <small>{new Date(r.created_at).toUTCString()}</small></p>)}</section>
      {team&&editable&&<Analysis issue={id} enabled={process.env.AI_ENABLED==='true'} fallback={process.env.AI_FALLBACK_ENABLED==='true'} primary="openrouter"/>}
    </div>
   </div>
  </RoomPanels></RoomTranscriptProvider>
  <section className="panel resolution-timeline"><header className="resolution-card-head"><span className="resolution-icon"><Clock3 size={17}/></span><div><h2>Activity timeline</h2><p>Every decision, in order.</p></div></header><ol className="activity">{rows(audit).map(a=><li key={a.id}><strong>{human(a.action)}</strong><span>{name(a.actor_id)}</span><time>{new Date(a.created_at).toUTCString()}</time></li>)}</ol></section>
 </div>;
}
