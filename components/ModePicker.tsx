import ModeButton from './ModeButton';
import {redirect} from 'next/navigation';
import {session} from '@/lib/db';
import {homeMode,modes} from '@/lib/modes';

async function chooseMode(form: FormData) {
  'use server';
  const {client,user}=await session();
  const mode=homeMode(form.get('mode'));
  const destination=form.get('stay')==='settings'?'/settings?notice=Home+view+saved.':mode==='communication'?'/communication':'/dashboard';
  if(user.user_metadata.home_mode===mode)redirect(destination);
  const {error}=await client.auth.updateUser({data:{home_mode:mode}});
  if(error)throw new Error('Could not save your home preference.');
  redirect(destination);
}

export default function ModePicker({current,descriptions=false,settings=false}:{current:unknown;descriptions?:boolean;settings?:boolean}) {
  return <form action={chooseMode} aria-label="Home view" className="mode-picker">
    {settings&&<input type="hidden" name="stay" value="settings"/>}
    {Object.entries(modes).map(([value,label])=><ModeButton key={value} value={value} selected={homeMode(current)===value}><strong>{label}</strong>{descriptions&&<span>{{explore:'See your rooms, tasks, and recent activity.',communication:'Find a conversation and message your team.',resolution:'Track issues, review evidence, and verify fixes.'}[value]}</span>}</ModeButton>)}
  </form>;
}
