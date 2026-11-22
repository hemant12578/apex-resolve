import ConfirmButton from '@/components/ConfirmButton';
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
    client.from('workspaces').select('name,description,owner_id,community_state').eq('id',id).maybeSingle(),
    client.from('workspace_members').select('user_id,role,profiles(display_name)').eq('workspace_id',id).neq('role','guest')
  ]);
  const people=rows(members), self=people.find(person=>person.user_id===user.id);
  if(!group.data || !self)notFound();
  const ownerId=group.data.owner_id;
  const owner=ownerId===user.id;
  const deletion=<Form op="deleteCommunity" fields={{workspace:id}}><p>Deleting this chat closes it for every member. Workspace issues and evidence are kept.</p><ConfirmButton prompt={'Delete '+group.data.name+' chat for everyone?'}>Delete group chat</ConfirmButton></Form>;
  if(group.data.community_state==='deleted')notFound();
  if(group.data.community_state==='closing'){
    if(!owner)notFound();
    return <section className="panel stack"><h1>Finish deleting {group.data.name}</h1><Feedback q={query}/>{deletion}</section>;
  }
  const names=Object.fromEntries(people.map(person=>['u'+person.user_id.replaceAll('-',''),(Array.isArray(person.profiles)?person.profiles[0]:person.profiles)?.display_name||'Member']));
  const admin=self.role==='admin';
  return <div className="community-chat messenger stack">
    <Link href="/communication">← Messages</Link>
    <header className="community-header"><UsersRound aria-hidden="true"/><div><h1>{group.data.name}</h1><small>{people.length} {people.length===1?'member':'members'} · {self.role}</small></div></header>
    <Feedback q={query}/>
    <div className="group-layout"><details className="panel group-info" open={Boolean(query.invitation || query.error || query.notice)}><summary>Community info</summary>
      {group.data.description&&<p>{group.data.description}</p>}
      <ul className="group-roster">{people.map(person=><li key={person.user_id}><span className="member-initial" aria-hidden="true">{(names['u'+person.user_id.replaceAll('-','')]||'M').slice(0,1)}</span><span>{names['u'+person.user_id.replaceAll('-','')]}</span><small>{person.user_id===ownerId?'owner':person.role}</small>
        {admin&&person.user_id!==ownerId&&person.user_id!==user.id&&<details className="role-control"><summary>Change role</summary>
          <Form op="role" fields={{workspace:id,view:'community',member:person.user_id}}>
            <label>Workspace and community role<select name="role" defaultValue={person.role}>{['member','verifier','admin'].map(role=><option key={role}>{role}</option>)}</select></label>
            <ConfirmButton prompt="Update this member’s role in the community and its workspace?">Update role</ConfirmButton>
          </Form></details>}</li>)}</ul>
      {admin&&<><Form op="invite" fields={{workspace:id,view:'community',role:'member'}}><Button>Create invitation link</Button></Form>
      {query.invitation&&<InviteLink token={query.invitation}/>}
      <details><summary>Community settings</summary><Form op="editWorkspace" fields={{workspace:id,view:'community'}}>
        <label>Name<input required name="title" maxLength={100} defaultValue={group.data.name}/></label>
        <label>Description<textarea name="description" defaultValue={group.data.description}/></label><Button>Save changes</Button>
      </Form>{owner&&deletion}</details></>}
    </details>
    <RoomTranscriptProvider><RoomChat issueId={id} workspace={id} sourcePath={'/communities/'+id} community memberNames={names}/><LinkedConversationIssues source={'/communities/'+id}/></RoomTranscriptProvider></div>
  </div>;
}
