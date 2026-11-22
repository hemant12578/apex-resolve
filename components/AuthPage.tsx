import Link from "next/link";
import Brand from "./Brand";
import FirebaseAuthForm from './FirebaseAuthForm';

export type AuthSearchParams = Promise<{error?: string; notice?: string}>;
export default async function AuthPage({ mode, searchParams }: {mode: "login"|"signup"; searchParams: AuthSearchParams}) {
  const {error, notice} = await searchParams;
  const signup = mode === "signup";
  return <main className="auth-screen"><header className="wrap"><Brand/></header>
    <section className="auth-card">
      <div className="eyebrow"><span className="signal-line"/>Workspace access</div>
      <h1>{signup ? "Create your account." : "Welcome back."}</h1>
      <p>{signup ? "Start a workspace or join your team’s resolution rooms." : "Sign in to your resolution workspace."}</p>
      {error && <div className="error" role="alert">{error}</div>}
      {notice && <div className="notice" role="status">{notice}</div>}
      <FirebaseAuthForm signup={signup}/>
      <div className="auth-switch">{signup ? "Already have an account?" : "New to Apex Resolve?"} <Link href={signup ? "/login" : "/signup"}>{signup ? "Sign in" : "Create an account"}</Link></div>
    </section>
  </main>;
}
