import Link from 'next/link';
import type {ReactNode} from 'react';
import {mutate} from '@/lib/actions';
export type Query=Record<string,string|undefined>;
export function Feedback({q}:{q:Query}){return q.error?<p className="error" role="alert">{q.error}</p>:q.notice?<p className="notice" role="status">{q.notice}</p>:null}
export function Form({op,fields,children}:{op:string,fields?:Record<string,string>,children:ReactNode}){
 return <form action={mutate} className="stack"><input type="hidden" name="op" value={op}/>{Object.entries(fields??{}).map(([k,v])=><input key={k} type="hidden" name={k} value={v}/>)}{children}</form>
}
export const statuses=['OPEN','IN_PROGRESS','PENDING_VERIFICATION','VERIFIED_RESOLVED'];
export const human=(s:string)=>s.toLowerCase().replaceAll('_',' ');
export function Status({s}:{s:string}){return <span className={'badge status-'+s.toLowerCase()}>{human(s)}</span>}
type Issue={id:string,title:string,status:string,priority:string,updated_at:string};
export function IssueList({issues}:{issues:Issue[]}){return issues.length?<div className="issue-list">{issues.map(i=><Link key={i.id} href={'/issues/'+i.id} className="issue-row"><div><small>{i.priority.toUpperCase()} PRIORITY</small><strong>{i.title}</strong></div><Status s={i.status}/></Link>)}</div>:<p className="muted">No issues are visible here yet.</p>}
export function Button({children}:{children:ReactNode}){return <button className="btn btn-primary">{children}</button>}
export function Names({people,value}:{people:{user_id:string,name:string}[],value?:string}){return <label>Assignee<select name="assignee" defaultValue={value??''}><option value="">Unassigned</option>{people.map(p=><option key={p.user_id} value={p.user_id}>{p.name}</option>)}</select></label>}
