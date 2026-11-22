'use server';
import {redirect} from 'next/navigation';
import {headers} from 'next/headers';
import {revalidatePath} from 'next/cache';
import {z} from 'zod';
import {db,session,storageAdmin} from './db';
import {validateEvidence} from './file-validation.mjs';

function field(f:FormData,key:string){return String(f.get(key)??'').trim()}
function message(path:string,error:string):never{return redirect(path+'?error='+encodeURIComponent(error))}
function uid(f:FormData,key:string){return z.uuid().parse(field(f,key))}
function title(f:FormData,max=180){return z.string().min(1).max(max).parse(field(f,'title'))}
function description(f:FormData){return z.string().max(8000).parse(field(f,'description'))}
async function appUrl(){
  const host=(await headers()).get('host');
  if(host==='localhost:3000'||host==='127.0.0.1:3000')return 'http://'+host;
  return process.env.NEXT_PUBLIC_APP_URL||'http://localhost:3000';
}
function authError(code:string|undefined,signup:boolean){
  if(code==='over_email_send_rate_limit')return 'Confirmation email limit reached. Try again later or ask the project admin to configure SMTP.';
  if(code==='email_address_invalid')return 'Use a deliverable email address.';
  if(code==='user_already_exists'||code==='email_exists')return 'An account with this email already exists. Sign in instead.';
  if(code==='invalid_credentials')return 'Check your email and password.';
  if(code==='email_not_confirmed')return 'Confirm your email before signing in.';
  return signup?'Registration could not finish. Please try again.':'Sign-in could not finish. Please try again.';
}
export async function authenticate(f:FormData){
  const signup=field(f,'mode')==='signup', path=signup?'/signup':'/login';
  const email=z.email().safeParse(field(f,'email')),password=String(f.get('password')??'');
  if(!email.success||!password||(signup&&password.length<8))message(path,'Enter a valid email and password'+(signup?' of at least eight characters.':'.'));
  const client=await db().catch(()=>message(path,'Configure Supabase in .env.local to use authentication.'));
  const result=signup?await client.auth.signUp({email:email.data,password,options:{emailRedirectTo:(await appUrl())+'/auth/confirm'}}):await client.auth.signInWithPassword({email:email.data,password});
  if(result.error)message(path,authError(result.error.code,signup));
  if(!result.data.session)redirect('/login?notice=Check+your+email+to+confirm+your+account.');
  redirect('/dashboard');
}
export async function googleSignIn(){
  const settings=await fetch(process.env.NEXT_PUBLIC_SUPABASE_URL!+'/auth/v1/settings',{headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!},cache:'no-store'}).then(r=>r.json()).catch(()=>null);
  if(!settings?.external?.google)message('/login','Google sign-in needs Google enabled in this Supabase project’s Auth providers. The Firebase console setting does not enable it here.');
  const client=await db();
  const {data,error}=await client.auth.signInWithOAuth({provider:'google',options:{redirectTo:(await appUrl())+'/auth/confirm'}});
  if(error||!data.url)message('/login','Google sign-in could not start. Enable Google in the Supabase Auth providers and configure its OAuth credentials.');
  redirect(data.url);
}
export async function logout(){const {client}=await session();const {error}=await client.auth.signOut({scope:'local'});if(error)message('/settings','Sign-out failed. Please retry.');redirect('/login')}
export async function resetPassword(f:FormData){
  const client=await db().catch(()=>message('/reset','Configure Supabase first.'));
  if(field(f,'mode')==='change'){
    const password=String(f.get('password')??'');
    if(password.length<8)message('/reset','Use at least eight characters.');
    const {error}=await client.auth.updateUser({password});if(error)message('/reset','The reset session has expired. Request another link.');
    redirect('/dashboard');
  }
  const email=z.email().safeParse(field(f,'email'));if(!email.success)message('/reset','Enter a valid email.');
  const {error}=await client.auth.resetPasswordForEmail(email.data,{redirectTo:(await appUrl())+'/auth/confirm?flow=reset'});
  if(error)message('/reset','Unable to request a link. Try again later.');
  redirect('/login?notice=If+the+account+exists,+a+reset+link+is+on+its+way.');
}
export async function mutate(f:FormData){
  const {client,user}=await session();
  let back='/dashboard', destination='', notice='Changes saved.';
  try{
    const op=field(f,'op');
    async function rpc(name:string,args:Record<string,unknown>){
      const {data,error}=await client.rpc(name,args);
      if(error)throw new Error(error.code==='P0001'?error.message:'The operation failed. Check your permissions and entries.');
      return data;
    }
    if(op==='workspace'||op==='community'){
      if(op==='community')back='/communities/new';
      const id=await rpc('create_workspace',{p_name:title(f,100),p_description:description(f)});
      destination=(op==='community'?'/communities/':'/workspaces/')+id;
    }else if(op==='profile'){
      back='/settings';await rpc('update_profile',{p_display_name:title(f,100)});
    }else if(['issue','invite','editWorkspace','role'].includes(op)){
      const wid=uid(f,'workspace');back=(field(f,'view')==='community'?'/communities/':'/workspaces/')+wid;
      if(op==='issue'){
        const source=field(f,'source');
        const sourceMatch=/^(\/issues\/|\/communities\/|\/communication\?contact=)([a-f0-9-]{36})#message-([A-Za-z0-9_%.-]{1,768})$/.exec(source);
        let body=description(f);
        if(source){
          if(!sourceMatch)throw new Error('Invalid message reference.');
          const [,kind,sourceId]=sourceMatch;
          if(kind==='/issues/'){
            const origin=await client.from('issues').select('workspace_id').eq('id',sourceId).maybeSingle();
            if(origin.data?.workspace_id!==wid)throw new Error('Source room unavailable.');
          }else if(kind==='/communities/'){
            if(sourceId!==wid)throw new Error('Select the source workspace.');
          }else{
            const origin=await client.from('contact_requests').select('sender,recipient').eq('id',sourceId).eq('status','accepted').maybeSingle();
            if(!origin.data||![origin.data.sender,origin.data.recipient].includes(user.id))throw new Error('Conversation unavailable.');
          }
          body+='\n\nSource message: '+source;
        }
        const id=await rpc('file_issue',{p_party:field(f,'party')||'unknown',p_people:f.getAll('affected').map(v=>z.uuid().parse(v)),p_workspace_id:wid,p_title:title(f),p_description:body,p_priority:field(f,'priority'),p_assignee_id:field(f,'assignee')||null,p_id:uid(f,'id')});
        destination='/issues/'+id;
      }else if(op==='invite'){
        const token=await rpc('create_invitation',{p_workspace_id:wid,p_role:field(f,'role'),p_issue_id:field(f,'sharedIssue')||null});
        destination=back+'?invitation='+encodeURIComponent(token);
      }else if(op==='role'){await rpc('set_member_role',{p_workspace_id:wid,p_user_id:uid(f,'member'),p_role:field(f,'role')});}else await rpc('update_workspace',{p_workspace_id:wid,p_name:title(f,100),p_description:description(f)});
    }else if(op==='accept'){
      const token=z.string().min(20).max(200).parse(field(f,'token'));
      back='/invite/'+encodeURIComponent(token);const id=await rpc('accept_invitation',{p_token:token});destination='/workspaces/'+id;
    }else{
      const issue=uid(f,'issue');back='/issues/'+issue;
      const {data:access,error:denied}=await client.rpc('can_access_issue',{p_issue_id:issue});
      if(denied||!access)throw new Error('Room access required.');
      if(op==='transition'){
        await rpc('transition_issue',{p_request_id:field(f,'reviewRequest')||null,p_issue_id:issue,p_action:field(f,'action'),p_notes:field(f,'notes'),p_tags:field(f,'tags').split(',').map(x=>x.trim()).filter(Boolean).slice(0,10)});
      }else if(op==='approveAi'){
        await rpc('approve_ai_task',{p_analysis_id:uid(f,'analysis'),p_index:z.coerce.number().int().min(0).max(7).parse(field(f,'index')),p_title:title(f),p_description:description(f)});
      }else if(op==='task'){
        await rpc('save_task',{p_issue_id:issue,p_title:title(f),p_description:description(f),p_status:field(f,'status'),p_assignee_id:field(f,'assignee')||null,p_id:field(f,'id')||null});
      }else if(op==='deleteTask'){
        await rpc('delete_task',{p_issue_id:issue,p_id:uid(f,'id')});
      }else if(op==='evidence'){
        const kind=field(f,'kind'),desc=z.string().min(1).max(4000).parse(description(f)),id=uid(f,'id');
        let value:string|null=field(f,'value')||null;
        if(kind==='file'){
          const {data:open}=await client.from('issues').select('status').eq('id',issue).single();
          if(!open||!['OPEN','IN_PROGRESS'].includes(open.status))throw new Error('Review or reopen the issue before uploading evidence.');
          const file=f.get('file');
          if(!(file instanceof File)||file.size>4194304)throw new Error('Choose a file up to 4 MiB.');
          const bytes=new Uint8Array(await file.arrayBuffer());
          const {ext,mime}=validateEvidence(file.name,file.type,bytes);value=issue+'/'+id+'.'+ext;
          const bucket=storageAdmin().storage.from('evidence');
          const {error}=await bucket.upload(value,bytes,{contentType:mime,metadata:{uploader_id:user.id}});
          if(error)throw new Error('Upload failed. Check storage configuration or reload to retry.');
          // Keep the private object on ambiguous database errors. A committed record may already reference it.
        }else if(kind==='url'){
          if(!value||!/^https:\/\//i.test(value)||!z.url().safeParse(value).success)throw new Error('Enter an HTTPS evidence URL.');
        }else if(kind==='note'){value=null;if(!desc)throw new Error('Write an evidence note.')}
        else throw new Error('Unknown evidence type.');
        await rpc('add_evidence',{p_issue_id:issue,p_kind:kind,p_description:desc,p_value:value,p_id:id});
        notice='Evidence attached.';
      }else throw new Error('Unknown action.');
    }
  }catch(err){
    message(back,err instanceof z.ZodError?'Check the required fields and their lengths.':err instanceof Error?err.message:'Unable to save changes.');
  }
  revalidatePath('/','layout');
  redirect(destination||back+'?notice='+encodeURIComponent(notice));
}

export async function issuePeople(workspace:string){
 const {client,user}=await session();
 const id=z.uuid().parse(workspace);
 const {data:membership}=await client.from('workspace_members').select('role').eq('workspace_id',id).eq('user_id',user.id).maybeSingle();
 if(!membership||membership.role==='guest')throw new Error('Workspace membership required.');
 const {data,error}=await client.from('workspace_members').select('user_id,role,profiles(display_name)').eq('workspace_id',id);
 if(error)throw new Error('Members unavailable.');
 return (data||[]).map(p=>({id:p.user_id,name:(Array.isArray(p.profiles)?p.profiles[0]:p.profiles)?.display_name||'Member',role:p.role,self:p.user_id===user.id}));
}
