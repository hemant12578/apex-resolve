"use client";

import { useState } from "react";
import { Check, CircleCheck, FileText, ListChecks, MessageCircle, ShieldCheck } from "lucide-react";

const stages = [
  { name: "Conversation", icon: MessageCircle, label: "Issue room", title: "Checkout failure after deployment", details: "The client reports a failed payment. The developer and verifier use the same room to agree on the expected outcome.", item: "A successful checkout should produce one confirmed payment." },
  { name: "Tasks", icon: ListChecks, label: "Assigned work", title: "Reproduce and fix the checkout", details: "The developer records the failing behavior and checks the payment callback after applying the fix.", item: "Run the checkout regression test against the repaired callback." },
  { name: "Evidence", icon: FileText, label: "Evidence review", title: "Review the regression test", details: "A test log links the completed work to the reported issue. Reviewers can inspect the evidence before making a decision.", item: "Checkout regression log · Text evidence" },
  { name: "Verification", icon: ShieldCheck, label: "Resolution review", title: "Confirm the checkout is working", details: "An authorized verifier reviews the evidence, records the decision, and makes the verified solution available to the team.", item: "Approval records the verifier, evidence, and review date." },
];

export default function WorkflowPreview() {
  const [selected, select] = useState(0);
  const stage = stages[selected];
  const Icon = stage.icon;
  return <div className="workflow-preview">
    <div className="preview-bar"><div className="preview-lamps" aria-hidden="true"><i/><i/><i/></div><span>Resolution room preview</span></div>
    <div className="preview-body">
      <div className="preview-nav" aria-label="Workflow stages">
        {stages.map((step, i) => <button key={step.name} type="button" aria-pressed={i===selected} onClick={()=>select(i)}><step.icon size={17} />{step.name}</button>)}
      </div>
      <div className="preview-content" aria-live="polite">
        <div className="preview-meta"><Icon size={17} /> {stage.label}</div>
        <h3>{stage.title}</h3><p>{stage.details}</p>
        <div className="preview-excerpt">{selected===3 ? <CircleCheck size={20}/> : <Check size={18}/>}<span>{stage.item}</span></div>
      </div>
    </div>
  </div>;
}
