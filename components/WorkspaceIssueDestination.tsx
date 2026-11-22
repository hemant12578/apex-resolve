'use client';

import {useState} from 'react';
import IssueResponsibility from './IssueResponsibility';

export default function WorkspaceIssueDestination({workspaces, initial}: {
  workspaces: {id: string; name: string}[];
  initial: string;
}) {
  const [workspace, setWorkspace] = useState(initial);
  return <>
    <label>Workspace<select name="workspace" value={workspace} onChange={event => setWorkspace(event.target.value)}>
      {workspaces.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
    </select></label>
    <IssueResponsibility key={workspace} workspace={workspace} assign/>
  </>;
}
