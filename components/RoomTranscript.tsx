'use client';

import {createContext,useCallback,useContext,useMemo,useState,type ReactNode} from 'react';

type Transcript = {id:string;text:string;time:number}[];
type Context = {messages:Transcript;setMessages:(messages:Transcript)=>void};
const RoomTranscriptContext=createContext<Context|null>(null);

export function RoomTranscriptProvider({children}:{children:ReactNode}) {
 const [messages,setMessages]=useState<Transcript>([]);
 const update=useCallback((next:Transcript)=>setMessages(next),[]);
 const value=useMemo(()=>({messages,setMessages:update}),[messages,update]);
 return <RoomTranscriptContext.Provider value={value}>{children}</RoomTranscriptContext.Provider>;
}

export function useRoomTranscript() {
 const context=useContext(RoomTranscriptContext);
 if(!context)throw new Error('Room transcript provider is missing.');
 return context;
}
