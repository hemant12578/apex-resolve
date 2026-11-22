'use client';
import {Sun,Moon} from 'lucide-react';
import {useState} from 'react';

export default function ThemeSwitch({initial}:{initial:'black'|'white'}) {
  const [theme,setTheme]=useState(initial);
  function toggle(){
    const next=theme==='black'?'white':'black';
    document.documentElement.dataset.theme=next;
    document.cookie='apex_theme='+next+'; Path=/; Max-Age=31536000; SameSite=Lax';
    setTheme(next);
  }
  return <button type="button" className="theme-switch" onClick={toggle} aria-label={'Switch to '+(theme==='black'?'white':'black')+' theme'}>{theme==='black'?<Sun size={17}/>:<Moon size={17}/>}</button>;
}
