'use client';
export default function ErrorPage({reset}:{reset:()=>void}){return <main className="page"><div className="panel stack"><h1>Unable to load this page</h1><p>Check your connection and project configuration, then try again.</p><button className="btn" onClick={reset}>Retry</button></div></main>}
