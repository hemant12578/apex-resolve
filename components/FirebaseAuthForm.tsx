'use client';
import {useState,type FormEvent} from 'react';
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  sendEmailVerification,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  updateProfile,
} from 'firebase/auth';
import {firebaseAuth} from '@/lib/firebase-client';
import Link from 'next/link';
import {useRouter} from 'next/navigation';
import {AtSign,Eye,EyeOff,LoaderCircle,Mail} from 'lucide-react';

function friendly(error:unknown){
  const code=typeof error==='object'&&error&&'code' in error?String((error as {code:unknown}).code):'';
  if(code.includes('email-already-in-use'))return 'That email already has an account. Sign in instead.';
  if(code.includes('invalid-credential')||code.includes('wrong-password')||code.includes('user-not-found'))return 'Check your email and password, then try again.';
  if(code.includes('too-many-requests'))return 'Too many attempts. Wait a minute and try again.';
  if(code.includes('popup-closed-by-user'))return 'Google sign-in was closed before it finished.';
  if(code.includes('network-request-failed'))return 'The network interrupted sign-in. Check your connection.';
  return error instanceof Error?error.message:'Authentication failed.';
}

export default function FirebaseAuthForm({signup}:{signup:boolean}){
  const router=useRouter();
  const [error,setError]=useState('');
  const [notice,setNotice]=useState('');
  const [busy,setBusy]=useState(false);
  const [show,setShow]=useState(false);
  const [username,setUsername]=useState('');

  async function finish(){
    const auth=firebaseAuth();const user=auth.currentUser;
    if(!user)throw new Error('Sign-in did not complete. Try again.');
    if(!user.emailVerified){await signOut(auth);throw new Error('Verify your email using the Firebase email, then sign in.');}
    const displayName=(user.displayName||username||'').trim();
    const response=await fetch('/api/auth/firebase',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({idToken:await user.getIdToken(true),displayName})});
    const result=await response.json() as {error?:string;firstLogin?:boolean;destination?:string};
    if(!response.ok)throw new Error(result.error||'Could not start your workspace session.');
    router.push(result.firstLogin?'/welcome':result.destination||'/dashboard');router.refresh();
  }

  async function emailSubmit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setError('');setNotice('');
    const form=new FormData(event.currentTarget);
    const email=String(form.get('email')||'').trim();
    const password=String(form.get('password')||'');
    const chosen=String(form.get('displayName')||'').trim();
    if(signup&&chosen.length<2){setError('Choose a username with at least two characters.');return}
    setBusy(true);
    try{
      const auth=firebaseAuth();
      if(signup){
        const {user}=await createUserWithEmailAndPassword(auth,email,password);
        if(chosen)await updateProfile(user,{displayName:chosen});
        await sendEmailVerification(user);
        await signOut(auth);
        setNotice('Account created. Firebase sent a verification link — open it, then sign in with your username ready.');
      }else{
        await signInWithEmailAndPassword(auth,email,password);
        await finish();
      }
    }catch(e){setError(friendly(e));}finally{setBusy(false);}
  }

  async function google(){
    setError('');setNotice('');setBusy(true);
    try{await signInWithPopup(firebaseAuth(),new GoogleAuthProvider());await finish();}
    catch(e){setError(friendly(e));}finally{setBusy(false);}
  }

  return <>
    <form onSubmit={emailSubmit} className="auth-form auth-form-v2">
      {signup&&<label className="auth-field"><span>Username</span><div className="auth-input-wrap"><AtSign size={17}/><input required minLength={2} maxLength={100} name="displayName" autoComplete="nickname" placeholder="maya.sharma" value={username} onChange={e=>setUsername(e.target.value)}/></div><small>This is how teammates find you. You can refine it later in Settings.</small></label>}
      <label className="auth-field"><span>Email address</span><div className="auth-input-wrap"><Mail size={17}/><input required autoComplete="email" type="email" maxLength={254} name="email" placeholder="you@company.com"/></div></label>
      <label className="auth-field"><span>Password</span><div className="auth-input-wrap"><input required minLength={signup?8:1} maxLength={128} autoComplete={signup?'new-password':'current-password'} type={show?'text':'password'} name="password" placeholder={signup?'At least 8 characters':'Enter your password'}/><button type="button" className="auth-eye" onClick={()=>setShow(!show)} aria-label={show?'Hide password':'Show password'}>{show?<EyeOff size={17}/>:<Eye size={17}/>}</button></div></label>
      {!signup&&<Link className="auth-reset" href="/reset">Forgot password?</Link>}
      <button className="btn btn-primary auth-submit" type="submit" disabled={busy}>{busy?<><LoaderCircle className="spin" size={18}/> Please wait…</>:signup?'Create account':'Sign in'}</button>
    </form>
    <div className="auth-or"><span>or</span></div>
    <button type="button" onClick={google} disabled={busy} className="btn btn-outline auth-google-btn"><span className="google-g" aria-hidden="true">G</span> Continue with Google</button>
    {error&&<div className="error" role="alert">{error}</div>}
    {notice&&<div className="notice" role="status">{notice}</div>}
  </>;
}
