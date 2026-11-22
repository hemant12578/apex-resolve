import {NextResponse} from 'next/server';
import {db,rows,storageAdmin} from '@/lib/db';
import {contactList} from '@/lib/contact-list';
import {memberHandle} from '@/lib/handles';

const respond=(body:object,status=200)=>NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});
export async function GET(request:Request){
  const section=new URL(request.url).searchParams.get('section');
  try{
    const client=await db(),{data:{user}}=await client.auth.getUser();
    if(!user)return respond({error:'Sign in to your workspace.'},401);
    if(section==='chats'){
      const contacts=(await contactList()).filter(c=>c.status==='accepted');
      const peers=contacts.slice(0,100).map(c=>c.peer);
      const people=peers.length?rows(await storageAdmin().from('profiles').select('id,display_name').in('id',peers).order('display_name')):[];
      return respond({items:people.map(p=>({title:p.display_name,detail:memberHandle(p.id,p.display_name),path:'/communication?tab=chats&peer='+p.id}))});
    }
    if(section==='groups'){
      const groups=rows(await client.from('workspaces').select('id,name,workspace_members!inner(user_id,role)').eq('workspace_members.user_id',user.id).neq('workspace_members.role','guest').eq('community_state','active').order('name').limit(100));
      return respond({items:groups.map(g=>({title:g.name,detail:g.workspace_members[0]?.role,path:'/communities/'+g.id}))});
    }
    if(section==='issues'){
      const issues=rows(await client.from('issues').select('id,title,status,priority').order('updated_at',{ascending:false}).limit(100));
      return respond({items:issues.map(i=>({title:i.title,detail:i.status.replaceAll('_',' ').toLowerCase()+' · '+i.priority,path:'/issues/'+i.id}))});
    }
    if(section==='knowledge'){
      const entries=rows(await client.from('knowledge_entries').select('issue_id,title,summary,issues!inner(legacy_review_required)').eq('issues.legacy_review_required',false).order('verified_at',{ascending:false}).limit(100));
      return respond({items:entries.map(e=>({title:e.title,detail:e.summary,path:'/issues/'+e.issue_id}))});
    }
    return respond({error:'Unknown directory.'},400);
  }catch{return respond({error:'Directory unavailable.'},503);}
}
