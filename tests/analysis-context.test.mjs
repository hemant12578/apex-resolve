import test from 'node:test';
import assert from 'node:assert/strict';
import {parseVisibleTranscript} from '../lib/analysis-context.ts';

test('visible Nexconn transcript fallback orders and deduplicates text without persisting it',()=>{
 const input=JSON.stringify([
  {id:'later',text:'Please fix the slow page',time:200},
  {id:'earlier',text:'The page is laggy',time:100},
  {id:'later',text:'duplicate',time:300},
 ]);
 assert.deepEqual(parseVisibleTranscript(input),['The page is laggy','Please fix the slow page']);
});

test('visible transcript rejects malformed or oversized browser input',()=>{
 assert.deepEqual(parseVisibleTranscript('{'),[]);
 assert.deepEqual(parseVisibleTranscript(JSON.stringify([{id:'a',text:'x',time:1,admin:true}])),[]);
 assert.deepEqual(parseVisibleTranscript(JSON.stringify([{id:'a',text:'x'.repeat(2001),time:1}])),[]);
 assert.deepEqual(parseVisibleTranscript(JSON.stringify(Array.from({length:51},(_,i)=>({id:String(i),text:'x',time:i+1})))),[]);
});
