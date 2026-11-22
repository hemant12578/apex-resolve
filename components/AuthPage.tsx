import Link from "next/link";
import Brand from "./Brand";
import FirebaseAuthForm from './FirebaseAuthForm';
import {BadgeCheck, LockKeyhole, MessagesSquare, ShieldCheck, Sparkles} from 'lucide-react';

export type AuthSearchParams = Promise<{error?: string; notice?: string}>;
export default async function AuthPage({ mode, searchParams }: {mode: "login"|"signup"; searchParams: AuthSearchParams}) {
  const {error, notice} = await searchParams;
  const signup = mode === "signup";
  return <main className="auth-screen auth-v2">
    <section className="auth-visual" aria-label="Why teams use Apex Resolve">
      <div className="auth-visual-glow" aria-hidden="true"/>
      <header className="auth-brand"><Brand/><span className="auth-brand-tag"><ShieldCheck size={14}/> Verified collaboration</span></header>
      <div className="auth-story">
        <p className="eyebrow"><span className="signal-line"/>Conversation → resolution</p>
        <h1>Every conversation<br/>ends in <em>proof.</em></h1>
        <p className="auth-lede">Chat privately, turn a report into tracked work, and let someone independent verify the fix. One calm workspace from first message to final sign-off.</p>
        <ul className="auth-points">
          <li><span><MessagesSquare/></span><div><strong>Familiar, fast messaging</strong><small>Direct chats, groups, communities and issue rooms.</small></div></li>
          <li><span><BadgeCheck/></span><div><strong>Independent verification</strong><small>The person who fixed it cannot approve it alone.</small></div></li>
          <li><span><LockKeyhole/></span><div><strong>Private by design</strong><small>Contact consent, private evidence and role-aware rooms.</small></div></li>
        </ul>
      </div>
      <div className="auth-demo" aria-hidden="true">
        <div className="auth-demo-head"><span className="auth-demo-avatar">M</span><div><strong>Maya · Checkout incident</strong><small><i/> Resolution room</small></div><span className="auth-demo-badge">Live</span></div>
        <div className="auth-demo-chat">
          <p className="auth-bubble in">Checkout is failing after the deploy. Screenshot attached.</p>
          <p className="auth-bubble out">Retest is green on staging. Requesting verification.<span>10:42 ✓✓</span></p>
          <p className="auth-bubble system"><ShieldCheck size={13}/> Verified by an independent reviewer</p>
        </div>
        <div className="auth-demo-foot"><Sparkles size={14}/> Apex AI suggests the next check</div>
      </div>
      <footer className="auth-visual-foot">Apex Resolve · from conversation to verified resolution</footer>
    </section>

    <section className="auth-panel">
      <div className="auth-panel-top">
        <Link href="/landing" className="auth-overview">Overview</Link>
        <span>{signup?'Already have an account?':'New to Apex Resolve?'} <Link href={signup?'/login':'/signup'}>{signup?'Sign in':'Create an account'}</Link></span>
      </div>
      <div className="auth-card">
        <div className="auth-card-mark"><Brand/></div>
        <p className="eyebrow"><span className="signal-line"/>{signup?'Start your workspace':'Welcome back'}</p>
        <h2>{signup ? "Create your account." : "Sign in to continue."}</h2>
        <p className="auth-sub">{signup ? "Choose your username now. It appears on every message, request and review." : "Your chats, rooms and verification queue are waiting."}</p>
        {error && <div className="error" role="alert">{error}</div>}
        {notice && <div className="notice" role="status">{notice}</div>}
        <FirebaseAuthForm signup={signup}/>
        <p className="auth-legal">By continuing you agree to keep shared evidence and member data confidential.</p>
      </div>
      <p className="auth-panel-foot"><ShieldCheck size={14}/> Independent review is enforced in the workspace, not just in the UI.</p>
    </section>
  </main>;
}
