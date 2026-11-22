'use client';
import {useState} from 'react';
import IssueResponsibility from './IssueResponsibility';
import {mutate} from '@/lib/actions';

export default function MessageIssue({workspace,destinations,sourcePath,issue,message,text}:{workspace?:string;destinations?:{id:string;name:string}[];sourcePath?:string;issue:string;message:string;text:string}) {
  const [draft,setDraft]=useState<string|null>(null);
  const [selected,setSelected]=useState(workspace||'');
  if(!draft)return <button type="button" className="btn" onClick={()=>setDraft(crypto.randomUUID())}>Create issue</button>;
  const reference=(sourcePath||'/issues/'+issue)+'#message-'+encodeURIComponent(message);
  return <form action={mutate} className="stack">
    <input type="hidden" name="op" value="issue"/>{destinations?<label>Share this excerpt with workspace<select required name="workspace" value={selected} onChange={e=>setSelected(e.target.value)}><option value="" disabled>Select workspace</option>{destinations.map(w=><option key={w.id} value={w.id}>{w.name}</option>)}</select></label>:<input type="hidden" name="workspace" value={workspace}/>}
    <input type="hidden" name="id" value={draft}/><input type="hidden" name="priority" value="medium"/>
    <input type="hidden" name="source" value={reference}/>
    <label>Issue title<input name="title" defaultValue={text.slice(0,180)} required maxLength={180}/></label>
    <label>Description<textarea name="description" defaultValue={text} required maxLength={3000}/></label>
    <IssueResponsibility key={selected} workspace={selected} assign/>
    <a href={reference}>Source message</a><button className="btn btn-primary">Confirm issue</button>
    <button type="button" className="btn" onClick={()=>setDraft(null)}>Cancel</button>
  </form>;
}
