import Link from 'next/link';
export default function Missing(){return <main className="page"><div className="panel"><h1>Page unavailable</h1><p>The resource may be private or no longer available.</p><Link className="btn" href="/dashboard">Dashboard</Link></div></main>}
