'use client';
import {useState,type FormEvent} from 'react';
import {createUserWithEmailAndPassword,GoogleAuthProvider,sendEmailVerification,signInWithEmailAndPassword,signInWithPopup,signOut} from 'firebase/auth';
import {firebaseAuth} from '@/lib/firebase-client';
import {Input} from './ui/input';
import {Button} from './ui/button';
import Link from 'next/link';
import {useRouter} from 'next/navigation';

export default function FirebaseAuthForm({signup}:{signup:boolean}){
  const router=useRouter();
  const [error,setError]=useState('');const [notice,setNotice]=useState('');const [busy,setBusy]=useState(false);
  async function finish(){
    const auth=firebaseAuth();const user=auth.currentUser;
    if(!user?.emailVerified){if(user)await signOut(auth);throw new Error('Verify your email using the Firebase email, then sign in.');}
    const response=await fetch('/api/auth/firebase',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({idToken:await user.getIdToken(true)})});
    const result=await response.json() as {error?:string;firstLogin?:boolean};
    if(!response.ok)throw new Error(result.error||'Could not start your workspace session.');
    router.push(result.firstLogin?'/welcome':'/dashboard');router.refresh();
  }
  async function emailSubmit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setError('');setNotice('');setBusy(true);
    try{
      const form=new FormData(event.currentTarget);const email=String(form.get('email')||'');const password=String(form.get('password')||'');const auth=firebaseAuth();
      if(signup){const {user}=await createUserWithEmailAndPassword(auth,email,password);await sendEmailVerification(user);await signOut(auth);setNotice('Firebase sent a verification email. Open it, then sign in.');}
      else{await signInWithEmailAndPassword(auth,email,password);await finish();}
    }catch(e){setError(e instanceof Error?e.message:'Authentication failed.');}finally{setBusy(false);}
  }
  async function google(){setError('');setNotice('');setBusy(true);try{await signInWithPopup(firebaseAuth(),new GoogleAuthProvider());await finish();}catch(e){setError(e instanceof Error?e.message:'Google sign-in failed.');}finally{setBusy(false);}}
  return <><form onSubmit={emailSubmit} className="stack auth-form">
    <label>Email address<Input required autoComplete="email" type="email" maxLength={254} name="email" placeholder="you@company.com"/></label>
    <label>Password<Input required minLength={signup?8:1} maxLength={128} autoComplete={signup?'new-password':'current-password'} type="password" name="password" placeholder={signup?'At least 8 characters':'Enter your password'}/></label>
    {!signup&&<Link className="auth-reset" href="/reset">Forgot password?</Link>}
    <Button className="btn btn-primary" type="submit" disabled={busy}>{signup?'Create account':'Sign in'}</Button>
  </form><div className="auth-google"><button type="button" onClick={google} disabled={busy} className="btn btn-outline">Continue with Google</button></div>
  {error&&<div className="error" role="alert">{error}</div>}{notice&&<div className="notice" role="status">{notice}</div>}</>;
}
