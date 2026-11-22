import ConversationSidebar from '@/components/ConversationSidebar';
import WorkspaceNav from '@/components/WorkspaceNav';
import ModePicker from '@/components/ModePicker';
import AccountMenu from '@/components/AccountMenu';
import {homeMode,modes} from '@/lib/modes';
import {memberHandle} from '@/lib/handles';
import Link from 'next/link';
import {Layers,Plus,Sparkles} from 'lucide-react';
import {session,rows} from '@/lib/db';
import './workspace.css';
export const dynamic="force-dynamic";

export default async function Layout({children}:{children:React.ReactNode}){
  const {client,user}=await session();
  const communication=homeMode(user.user_metadata.home_mode)==='communication';
  const query=client.from('workspaces').select('id,name,workspace_members!inner(role,user_id)').eq('workspace_members.user_id',user.id).order('name');
  const [workspaces,profile]=await Promise.all([
    rows(await (communication?query.neq('community_state','deleted'):query)),
    client.from('profiles').select('display_name').eq('id',user.id).maybeSingle()
  ]);
  const name=profile.data?.display_name||'Team member';
  return <div className="app-shell">
    <a className="skip-workspace" href="#workspace-main">Skip to content</a>
    <aside className="sidebar">
      <Link className="shell-brand" href="/"><span className="shell-brand-mark"><Layers/></span><span>Apex<span>Resolve</span></span></Link>
      <WorkspaceNav/>
      <ConversationSidebar/>
      <details open className="workspace-links"><summary>{communication?'Communities':'Workspaces'}</summary>{workspaces.map(w=><Link key={w.id} href={(communication&&w.workspace_members[0]?.role!=='guest'?'/communities/':'/workspaces/')+w.id}><span className="workspace-dot"/>{w.name}</Link>)}<Link className="workspace-create" href="/communities/new"><Plus size={15}/> Create community</Link></details>
      <div className="sidebar-foot"><span className="sidebar-ai"><Sparkles size={15}/> Apex AI</span><small>Conversation → verified fix</small></div>
    </aside>
    <div className="app-main">
      <header className="topbar">
        <div className="topbar-view"><span className="topbar-label">Home</span><ModePicker current={user.user_metadata.home_mode}/><span className="topbar-current">{modes[homeMode(user.user_metadata.home_mode)]}</span></div>
        <AccountMenu email={user.email||''} name={name} handle={memberHandle(user.id,name)}/>
      </header>
      <main id="workspace-main" tabIndex={-1} className="page">{children}</main>
    </div>
  </div>;
}
