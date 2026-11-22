import Link from 'next/link';
import {session,rows} from '@/lib/db';
export default async function Knowledge({searchParams}:{searchParams:Promise<{q?:string}>}){
 const {client}=await session(),q=((await searchParams).q||'').trim().slice(0,200);
 let query=client.from('knowledge_entries').select('issue_id,title,description,summary,tags,verified_at,issues!inner(legacy_review_required)').eq('issues.legacy_review_required',false).order('verified_at',{ascending:false});
 if(q)query=query.textSearch('search_vector',q,{type:'websearch',config:'simple'});
 const entries=rows(await query.limit(100));
 return <div className="stack"><header className="page-header"><h1>Verified knowledge</h1><p>Search solutions approved by your workspace verifiers.</p></header><form className="row"><input aria-label="Search verified solutions" name="q" defaultValue={q} placeholder="Search titles, keywords or tags"/><button className="btn">Search</button></form>{entries.map(e=><article className="panel stack" key={e.issue_id}><small>Verified {new Date(e.verified_at).toLocaleDateString('en-GB')}</small><h2><Link href={'/issues/'+e.issue_id}>{e.title}</Link></h2><p>{e.summary}</p><div>{e.tags?.join(' · ')}</div></article>)}{!entries.length&&<p className="panel">{q?'No matching solutions.':'Approved resolutions will appear here.'}</p>}</div>
}
