'use client';
import {Suspense,useState,type FormEvent} from 'react';
import {confirmPasswordReset,sendPasswordResetEmail,verifyPasswordResetCode} from 'firebase/auth';
import {firebaseAuth} from '@/lib/firebase-client';
import Link from 'next/link';
import {useSearchParams} from 'next/navigation';

export default function Reset(){return <Suspense fallback={<main className="page"><section className="panel">Loading password reset…</section></main>}><ResetForm/></Suspense>}
function ResetForm(){
 const code=useSearchParams().get('oobCode');
 const [notice,setNotice]=useState('');const [error,setError]=useState('');const [busy,setBusy]=useState(false);
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();setError('');setNotice('');setBusy(true);
  try{const form=new FormData(event.currentTarget);if(code){await verifyPasswordResetCode(firebaseAuth(),code);await confirmPasswordReset(firebaseAuth(),code,String(form.get('password')||''));setNotice('Password updated. You can sign in now.');}
   else{await sendPasswordResetEmail(firebaseAuth(),String(form.get('email')||''));setNotice('If the account exists, Firebase sent a reset email.');}}
  catch(e){setError(e instanceof Error?e.message:'Password reset failed.');}finally{setBusy(false);}
 }
 return <main className="page"><section className="panel stack"><h1>Reset password</h1>{error&&<p role="alert">{error}</p>}{notice&&<p role="status">{notice}</p>}
  <form className="stack" onSubmit={submit}>{code?<label>New password<input name="password" type="password" autoComplete="new-password" minLength={8} required/></label>:<label>Email<input name="email" type="email" required/></label>}
   <button className="btn btn-primary" disabled={busy}>{code?'Update password':'Send reset link'}</button></form><Link href="/login">Back to sign in</Link></section></main>;
}
