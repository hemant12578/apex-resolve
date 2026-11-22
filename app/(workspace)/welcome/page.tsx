import {onboard} from '@/lib/actions';
import {session} from '@/lib/db';
import {homeMode} from '@/lib/modes';
import {ClipboardList,Compass,MessagesSquare,ShieldCheck,Sparkles,UserRound} from 'lucide-react';

const choices=[
  {value:'explore',label:'Explorer',copy:'See your rooms, tasks and recent activity in one calm overview.',icon:Compass},
  {value:'communication',label:'Communication',copy:'Open a familiar messenger: chats, groups, communities and rooms.',icon:MessagesSquare},
  {value:'resolution',label:'Resolution',copy:'Track issues, evidence and independent review from one queue.',icon:ClipboardList},
] as const;

export default async function Welcome({searchParams}:{searchParams:Promise<{error?:string}>}){
  const {user,client}=await session();
  const {error}=await searchParams;
  const {data:profile}=await client.from('profiles').select('display_name').eq('id',user.id).maybeSingle();
  const current=homeMode(user.user_metadata.home_mode);
  const suggested=profile?.display_name&&profile.display_name!=='Team member'?profile.display_name:'';
  return <div className="onboard-shell">
    <section className="onboard-card">
      <header className="onboard-head">
        <span className="onboard-mark"><ShieldCheck/></span>
        <div><p className="eyebrow"><span className="signal-line"/>One-minute setup</p><h1>Make this workspace yours.</h1><p>Pick the name teammates will see and the view you want to open first. You can change both later.</p></div>
      </header>
      {error&&<p className="error" role="alert">{error}</p>}
      <form action={onboard} className="onboard-form">
        <label className="onboard-name"><span><UserRound size={17}/> Your username</span><input name="display_name" required minLength={2} maxLength={100} defaultValue={suggested} placeholder="maya.sharma" autoComplete="nickname"/><small>Shown on messages, chat requests and reviews.</small></label>
        <fieldset className="onboard-choices"><legend>Start me in</legend>{choices.map(({value,label,copy,icon:Icon})=><label key={value} className="onboard-choice"><input type="radio" name="mode" value={value} defaultChecked={current===value}/><span className="onboard-choice-icon"><Icon/></span><span><strong>{label}</strong><small>{copy}</small></span><i aria-hidden="true"/></label>)}</fieldset>
        <div className="onboard-foot"><p><Sparkles size={15}/> Everything stays connected whichever view you choose.</p><button className="btn btn-primary">Enter workspace</button></div>
      </form>
    </section>
    <p className="onboard-note"><ShieldCheck size={14}/> Your username is already attached to this account. It is not a second login.</p>
  </div>;
}
