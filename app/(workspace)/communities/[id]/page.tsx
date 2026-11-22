import LinkedConversationIssues from '@/components/LinkedConversationIssues';
import {notFound} from 'next/navigation';
import Link from 'next/link';
import {UsersRound} from 'lucide-react';
import RoomChat from '@/components/RoomChat';
import {RoomTranscriptProvider} from '@/components/RoomTranscript';
import {Button,Feedback,Form,type Query} from '@/components/WorkspaceUI';
import {rows,session} from '@/lib/db';
import InviteLink from '@/components/InviteLink';

export default async function Community({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<Query>}) {
  const {id}=await params, {client,user}=await session(), query=await searchParams;
  const [group,members]=await Promise.all([
    client.from('workspaces').select('name,description').eq('id',id).maybeSingle(),
    client.from('workspace_members').select('user_id,role,profiles(display_name)').eq('workspace_id',id).neq('role','guest')
  ]);
  const people=rows(members), self=people.find(person=>person.user_id===user.id);
  if(!group.data || !self)notFound();
  const names=Object.fromEntries(people.map(person=>['u'+person.user_id.replaceAll('-',''),(Array.isArray(person.profiles)?person.profiles[0]:person.profiles)?.display_name||'Member']));
  const admin=self.role==='admin';
  return <div className="community-chat messenger stack">
    <Link href="/communication">← Messages</Link>
    <header className="community-header"><UsersRound aria-hidden="true"/><div><h1>{group.data.name}</h1><small>{people.length} {people.length===1?'member':'members'} · {self.role}</small></div></header>
    <Feedback q={query}/>
    <div className="group-layout"><details className="panel group-info" open={Boolean(query.invitation || query.error)}><summary>Community info</summary>
      {group.data.description&&<p>{group.data.description}</p>}
      <ul className="group-roster">{people.map(person=><li key={person.user_id}><span className="member-initial" aria-hidden="true">{(names['u'+person.user_id.replaceAll('-','')]||'M').slice(0,1)}</span><span>{names['u'+person.user_id.replaceAll('-','')]}</span><small>{person.role}</small></li>)}</ul>
      {admin&&<><Form op="invite" fields={{workspace:id,view:'community',role:'member'}}><Button>Create invitation link</Button></Form>
      {query.invitation&&<InviteLink token={query.invitation}/>}
      <details><summary>Community settings</summary><Form op="editWorkspace" fields={{workspace:id,view:'community'}}>
        <label>Name<input required name="title" maxLength={100} defaultValue={group.data.name}/></label>
        <label>Description<textarea name="description" defaultValue={group.data.description}/></label><Button>Save changes</Button>
      </Form></details></>}
    </details>
    <RoomTranscriptProvider><RoomChat issueId={id} workspace={id} sourcePath={'/communities/'+id} community memberNames={names}/><LinkedConversationIssues source={'/communities/'+id}/></RoomTranscriptProvider></div>
  </div>;
}
