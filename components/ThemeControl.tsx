'use client';
import {Moon,Sun} from 'lucide-react';
import {useState} from 'react';

export default function ThemeControl({initial}:{initial:'black'|'white'}){
  const [theme,setTheme]=useState(initial);
  function choose(next:'black'|'white'){
    document.documentElement.dataset.theme=next;
    document.cookie='apex_theme='+next+'; Path=/; Max-Age=31536000; SameSite=Lax';
    setTheme(next);
  }
  return <div className="theme-control" role="group" aria-label="Appearance">
    <button type="button" aria-pressed={theme==='black'} onClick={()=>choose('black')} className="theme-option theme-option-dark"><span className="theme-swatch"><i/><i/><i/></span><span><Moon size={16}/><strong>Midnight</strong><small>Low-light workspace with warm accents.</small></span></button>
    <button type="button" aria-pressed={theme==='white'} onClick={()=>choose('white')} className="theme-option theme-option-light"><span className="theme-swatch"><i/><i/><i/></span><span><Sun size={16}/><strong>Daylight</strong><small>Bright, high-contrast paper theme.</small></span></button>
  </div>;
}
