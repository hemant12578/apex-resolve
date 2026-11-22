'use client';
export default function ConfirmButton({prompt,children}:{prompt:string,children:React.ReactNode}){return <button className="btn" onClick={e=>{if(!window.confirm(prompt))e.preventDefault()}}>{children}</button>}
