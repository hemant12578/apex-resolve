'use client';
import {useActionState} from 'react';
import {assessProof} from '@/lib/proofguard';
export default function ProofGuard({issue}:{issue:string}){
 const [state,action,pending]=useActionState(assessProof,{});
 return <details className="panel proofguard"><summary>ProofGuard · AI assessment</summary>
 <form action={action} className="stack"><input type="hidden" name="issue" value={issue}/>
 <label><input required type="checkbox" name="consent" value="yes"/> Share the issue title and up to eight evidence descriptions with OpenRouter.</label>
 <button disabled={pending} className="btn">{pending?'Assessing evidence…':'Assess evidence'}</button></form>
 <div aria-live="polite">{state.error&&<p>{state.error}</p>}{state.result&&<><p>{state.result.summary}</p>
 <p>Evidence references: {state.result.references.join(', ')||'None'}</p>
 {(['missing','contradictions','checks'] as const).map(k=><section key={k}><strong>{{missing:'Missing proof',contradictions:'Possible contradictions',checks:'Suggested checks'}[k]}</strong><ul>{state.result![k].map((v,i)=><li key={i}>{v}</li>)}</ul></section>)}
 <p>Uncertainty: {state.result.uncertainty}</p></>}</div></details>
}
