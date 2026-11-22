import ConversationSidebar from '@/components/ConversationSidebar';

import WorkspaceNav from '@/components/WorkspaceNav';
import ModePicker from '@/components/ModePicker';
import {homeMode,modes} from '@/lib/modes';
import Link from 'next/link';
import {Layers,LogOut} from 'lucide-react';
import {session,rows} from '@/lib/db';
import {logout} from '@/lib/actions';
import './workspace.css';
export const dynamic="force-dynamic";
export default async function Layout({children}:{children:React.ReactNode}){
 const {client,user}=await session(),workspaces=rows(await client.from('workspaces').select('id,name').order('name'));
 const communication=homeMode(user.user_metadata.home_mode)==='communication';
 return <div className="app-shell"><a className="skip-workspace" href="#workspace-main">Skip to content</a><aside className="sidebar"><Link className="shell-brand" href="/"><Layers/> Apex Resolve</Link><WorkspaceNav/><ConversationSidebar/><details open className="workspace-links"><summary>{communication?'Communities':'Workspaces'}</summary>{workspaces.map(w=><Link key={w.id} href={'/workspaces/'+w.id}>{w.name}</Link>)}<Link href="/communities/new">＋ Create community</Link></details></aside><div className="app-main"><header className="topbar"><details className="switch-view"><summary>{modes[homeMode(user.user_metadata.home_mode)]} view</summary><ModePicker current={user.user_metadata.home_mode}/></details><details className="account"><summary>{user.email}</summary><form action={logout}><button className="btn"><LogOut size={16}/>Sign out</button></form></details></header><main id="workspace-main" tabIndex={-1} className="page">{children}</main></div></div>
}
