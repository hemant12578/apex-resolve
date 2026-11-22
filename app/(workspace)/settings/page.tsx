import ContactIdentity from '@/components/ContactIdentity';
import {memberHandle} from '@/lib/handles';
import ModePicker from '@/components/ModePicker';
import ThemeControl from '@/components/ThemeControl';
import {session} from '@/lib/db';
import {Form,Button,Feedback,type Query} from '@/components/WorkspaceUI';
import {cookies} from 'next/headers';
import {BellRing,Palette,ShieldCheck,UserRound} from 'lucide-react';

export default async function Settings({searchParams}:{searchParams:Promise<Query>}){
  const {user,client}=await session();
  const {data,error}=await client.from('profiles').select('display_name').eq('id',user.id).single();
  if(error)throw new Error('Profile unavailable.');
  const {data:pin,error:pinError}=await client.rpc("my_contact_pin");
  const theme=(await cookies()).get('apex_theme')?.value==='white'?'white':'black';
  return <div className="stack settings-v2">
    <header className="page-header settings-head"><div><p className="eyebrow"><span className="signal-line"/>Account</p><h1>Settings</h1><p>Your identity, chat access, home view and appearance.</p></div><span className="settings-chip"><ShieldCheck size={15}/> Private by default</span></header>
    <Feedback q={await searchParams}/>
    <div className="settings-grid">
      <section className="panel settings-card"><header><span className="settings-icon"><UserRound/></span><div><h2>Profile</h2><p>The name teammates see in chats and reviews.</p></div></header><Form op="profile"><label>Email<input value={user.email} readOnly/></label><label>Username<input name="title" required minLength={2} maxLength={100} defaultValue={data.display_name}/></label><Button>Save profile</Button></Form></section>
      <ContactIdentity handle={memberHandle(user.id,data.display_name)} pin={pin} setupPending={pinError?.code==='PGRST202'}/>
      <section className="panel settings-card"><header><span className="settings-icon"><Palette/></span><div><h2>Appearance</h2><p>Choose the surface that feels right. Saved on this browser.</p></div></header><ThemeControl initial={theme}/></section>
      <section className="panel settings-card"><header><span className="settings-icon"><BellRing/></span><div><h2>Preferred home view</h2><p>Where the app opens after sign-in.</p></div></header><ModePicker settings current={user.user_metadata.home_mode}/></section>
    </div>
    <p className="settings-note"><ShieldCheck size={15}/> Open a workspace in the sidebar to manage its members, invitations and evidence policy.</p>
  </div>;
}
