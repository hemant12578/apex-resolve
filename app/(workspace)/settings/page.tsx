import ContactIdentity from '@/components/ContactIdentity';
import {memberHandle} from '@/lib/handles';
import ModePicker from '@/components/ModePicker';
import {session} from '@/lib/db';
import {Form,Button,Feedback,type Query} from '@/components/WorkspaceUI';
export default async function Settings({searchParams}:{searchParams:Promise<Query>}){
 const {user,client}=await session();const {data,error}=await client.from('profiles').select('display_name').eq('id',user.id).single();
 if(error)throw new Error('Profile unavailable.');
 const {data:pin,error:pinError}=await client.rpc("my_contact_pin");
 return <div className="stack"><header className="page-header"><h1>Settings</h1><p>Manage your account profile.</p></header><Feedback q={await searchParams}/><ContactIdentity handle={memberHandle(user.id,data.display_name)} pin={pin} setupPending={pinError?.code==='PGRST202'}/><section className="panel"><Form op="profile"><label>Email<input value={user.email} readOnly/></label><label>Display name<input name="title" required maxLength={100} defaultValue={data.display_name}/></label><Button>Save profile</Button></Form></section><section className="panel"><h2>Preferred home view</h2><ModePicker settings current={user.user_metadata.home_mode}/></section><p>Open a workspace in the sidebar to manage its settings and invitations.</p></div>
}
