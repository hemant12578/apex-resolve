import assert from 'node:assert/strict';
import test from 'node:test';
import {analyzeMessages,cleanMessages} from '../lib/analysis-provider.ts';
const env={GEMINI_API_KEY:'test-primary',OPENROUTER_API_KEY:'test-fallback',AI_FALLBACK_ENABLED:'true'};
const consent={gemini:true,fallback:true};
const result={summary:'Checkout error reported.',hypotheses:[],tasks:[{title:'Review checkout logs',description:'Locate the failing callback.'}],nextSteps:[],decisions:[]};
const success=()=>Response.json({choices:[{message:{content:JSON.stringify(result)}}],usage:{prompt_tokens:19,completion_tokens:30}});
test('Gemini response is validated and usage recorded',async()=>{
 const a=await analyzeMessages(['Checkout failed'],consent,env,async(url,options)=>{
 assert.match(url,/googleapis/);assert.equal(JSON.parse(options.body).messages[0].role,'system');return success()});
 assert.deepEqual(a,{provider:'gemini',result,inputTokens:19,outputTokens:30});
});
for(const mode of ['quota','timeout'])test('Fallback on '+mode+' only with consent',async()=>{
 let count=0;const run=async()=>{if(++count===1){if(mode==='timeout')throw new DOMException('timeout','TimeoutError');return new Response(null,{status:429})}return success()};
 assert.equal((await analyzeMessages(['hi'],consent,env,run)).provider,'openrouter');assert.equal(count,2);
 count=0;await assert.rejects(analyzeMessages(['hi'],{gemini:true,fallback:false},env,run));assert.equal(count,1);
});
test('Both unavailable stops after two attempts',async()=>{let count=0;await assert.rejects(analyzeMessages(['hi'],consent,env,async()=>{count++;return new Response(null,{status:503})}));assert.equal(count,2)});
test('Missing consent, invalid output and paid fallback are rejected',async()=>{
 let count=0;const invalid=async()=>{count++;return Response.json({choices:[{message:{content:'{}'}}]})};
 await assert.rejects(analyzeMessages(['hi'],{gemini:false,fallback:true},env,invalid),/consent/);assert.equal(count,0);
 await assert.rejects(analyzeMessages(['hi'],consent,env,invalid),/invalid_output/);assert.equal(count,1);
 await assert.rejects(analyzeMessages(['hi'],consent,{...env,OPENROUTER_MODEL:'paid'},async()=>new Response(null,{status:503})),/configuration/);
});
test('Only bounded, redacted context is used',()=>{assert.deepEqual(cleanMessages(['old','contact me@sample.org'],1),['contact [email]']);assert.equal(cleanMessages(['a'.repeat(2000)],50)[0].length,650)});
test('OpenRouter can be primary only with explicit consent and a free route',async()=>{
 const primary={...env,AI_PRIMARY_PROVIDER:'openrouter',OPENROUTER_MODEL:'openrouter/free'};
 let calls=0;
 const request=async(url,options)=>{calls++;assert.match(url,/openrouter/);assert.equal(JSON.parse(options.body).model,'openrouter/free');return success()};
 await assert.rejects(analyzeMessages(['hi'],{gemini:true,fallback:false},primary,request),/consent_required/);
 assert.equal(calls,0);
 assert.equal((await analyzeMessages(['hi'],{gemini:false,openrouter:true,fallback:false},primary,request)).provider,'openrouter');
 assert.equal(calls,1);
 await assert.rejects(analyzeMessages(['hi'],{gemini:false,openrouter:true,fallback:false},{...primary,OPENROUTER_MODEL:'paid/model'},request),/configuration/);
 assert.equal(calls,1);
});
