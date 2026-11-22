'use client';
import {useFormStatus} from 'react-dom';
import type {ReactNode} from 'react';

export default function ModeButton({value,selected,children}:{value:string;selected:boolean;children:ReactNode}) {
  const {pending,data}=useFormStatus();
  return <button name="mode" value={value} aria-pressed={selected} disabled={pending}>
    {children}{pending&&data?.get('mode')===value&&<small role="status">Opening view…</small>}
  </button>;
}
