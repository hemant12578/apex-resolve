import ResolutionScene from "@/components/ResolutionScene";
import Link from "next/link";
import { BookOpenCheck, Fingerprint, UsersRound, Layers3, MessageSquareText, ShieldCheck } from "lucide-react";
import Brand from "@/components/Brand";
import WorkflowPreview from "@/components/WorkflowPreview";

export default function Home() {
  return <div className="landing">
    <a className="skip-link" href="#main">Skip to content</a>
    <header className="public-nav wrap"><Brand/>
      <nav aria-label="Main navigation"><a href="#communication">Communication</a><a href="#workflow">Resolution</a><a href="#verification">Verification</a></nav>
      <div className="nav-actions"><Link className="login-link" href="/login">Sign in</Link><Link className="btn btn-primary nav-cta" href="/signup">Get started</Link></div>
    </header>
    <main id="main">
      <section className="hero">
        <div className="hero-layout wrap">
          <div className="hero-copy"><div className="eyebrow"><span className="signal-line"/>Team communication &amp; resolution</div>
            <h1>Team chats.<br/>Shared spaces.<br/><em>Verified</em> fixes.</h1>
            <p>Message a friend, bring your community together, or work through a problem with your team.</p>
            <div className="hero-actions"><Link className="btn btn-primary" href="/signup">Create an account</Link><a className="btn btn-outline" href="#workflow"><Layers3 size={17}/>Explore workflow</a></div>
          </div>
          <ResolutionScene/>
        </div>
      </section>
      <section className="wrap entry-section" id="communication">
        <h2>Where do you want to start?</h2>
        <div className="entry-options">
          <Link href="/communication?tab=chats"><MessageSquareText/><h3>Private messages</h3><p>Connect by username. Use a contact PIN or approve a request to start talking.</p><span>Open chats →</span></Link>
          <Link href="/communities/new"><UsersRound/><h3>Community chats</h3><p>Create a shared space, invite members and keep group replies in context.</p><span>Create community →</span></Link>
          <a href="#workflow"><ShieldCheck/><h3>Resolution rooms</h3><p>Turn a report into an issue, collect evidence and ask a teammate to verify the fix.</p><span>Try the workflow ↓</span></a>
        </div>
      </section>
      <section className="workflow-section wrap" id="workflow">
        <div className="section-heading"><div><div className="eyebrow"><span className="signal-line"/>The workflow</div><h2>Inside a resolution room.</h2></div><p>Explore a checkout issue from the initial report through its final review.</p></div>
        <WorkflowPreview/>
      </section>
      <section className="verification-section wrap" id="verification">
        <div className="eyebrow"><span className="signal-line"/>Verification</div><h2>Every resolution has a record.</h2>
        <div className="benefits">
          <article><MessageSquareText/><h3>One shared conversation</h3><p>A dedicated Nexconn room keeps each issue’s discussion with the work it informs.</p></article>
          <article><Fingerprint/><h3>Proof before approval</h3><p>Reviewers inspect the submitted evidence before signing off on a resolution.</p></article>
          <article><BookOpenCheck/><h3>Answers worth keeping</h3><p>Verified solutions give teams a searchable record of what worked.</p></article>
        </div>
        <div className="closing"><ShieldCheck size={32}/><div><h2>Open your workspace.</h2><p>Choose your home view after signing in.</p></div><Link className="btn btn-primary" href="/signup">Get started</Link></div>
      </section>
    </main>
    <footer className="public-footer wrap"><Brand/><span>From conversation to verified resolution.</span><a href="#main">Back to top</a></footer>
  </div>;
}
