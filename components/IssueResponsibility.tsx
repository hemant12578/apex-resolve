'use client';
import {useEffect,useState} from 'react';
import {issuePeople} from '@/lib/actions';
type People=Awaited<ReturnType<typeof issuePeople>>;
export default function IssueResponsibility({workspace,people,assign=false}:{workspace:string;people?:People;assign?:boolean}){
 const [party,setParty]=useState('unknown'),[loaded,setLoaded]=useState<People>([]),[error,setError]=useState('');
 useEffect(()=>{
   if(people||!workspace)return;
   let current=true;
   issuePeople(workspace).then(result=>{if(current)setLoaded(result)}).catch(()=>{if(current)setError('Unable to load members. Reopen the form to retry.')});
   return ()=>{current=false};
 },[people,workspace]);
 const options=people||loaded;
 return <><label>Who is affected?<select name="party" value={party} onChange={e=>setParty(e.target.value)}>
 <option value="unknown">External or unknown</option><option value="me">Me</option><option value="another">Someone else</option><option value="multiple">Multiple people</option></select></label>
 {(party==='multiple'||party==='another')&&<label>Affected people<select key={party} multiple={party==='multiple'} name="affected" required>{options.filter(p=>party==='multiple'||!p.self).map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>}
 {assign&&<label>Resolver<select name="assignee"><option value="">Person who starts work</option>{options.filter(p=>p.role!=='guest').map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>}
 {error&&<small role="alert">{error}</small>}</>;
}
