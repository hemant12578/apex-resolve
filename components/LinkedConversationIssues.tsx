import Link from 'next/link';
import {session,rows} from '@/lib/db';
import {Status} from './WorkspaceUI';

export default async function LinkedConversationIssues({source}:{source:string}){
  const {client}=await session();
  const issues=rows(await client.from('issues').select('id,title,status')
    .like('description','%Source message: '+source+'#message-%').order('updated_at',{ascending:false}).limit(30));
  return <details className="thread-analysis"><summary>Linked issues ({issues.length})</summary>
    {issues.length?<ul>{issues.map(issue=><li key={issue.id}><Link href={'/issues/'+issue.id}>{issue.title}</Link> <Status s={issue.status}/></li>)}</ul>:<p>Choose Create issue on a message to link a resolution here.</p>}
  </details>;
}
