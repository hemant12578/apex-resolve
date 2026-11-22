import 'server-only';
import {createPublicKey,verify} from 'node:crypto';

type Claims={aud?:string;iss?:string;sub?:string;email?:string;email_verified?:boolean;exp?:number;iat?:number;auth_time?:number};
type Key={kid:string;kty:string;n:string;e:string;alg?:string;use?:string};
export async function verifiedFirebaseEmail(token:string){
  const project=process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  if(!project||token.length>10000)throw new Error('Firebase is not configured.');
  const parts=token.split('.');
  if(parts.length!==3)throw new Error('Invalid identity token.');
  const header=JSON.parse(Buffer.from(parts[0],'base64url').toString()) as {alg?:string;kid?:string};
  const claims=JSON.parse(Buffer.from(parts[1],'base64url').toString()) as Claims;
  const now=Math.floor(Date.now()/1000);
  if(header.alg!=='RS256'||!header.kid||claims.aud!==project||claims.iss!==`https://securetoken.google.com/${project}`||!claims.sub||claims.sub.length>128||!claims.email||claims.email_verified!==true||!claims.exp||claims.exp<=now||!claims.iat||claims.iat>now||!claims.auth_time||claims.auth_time>now)throw new Error('Verify your email in Firebase before signing in.');
  const response=await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',{next:{revalidate:300}});
  if(!response.ok)throw new Error('Could not verify Firebase identity.');
  const keys=(await response.json()) as {keys:Key[]};
  const jwk=keys.keys.find(key=>key.kid===header.kid&&key.kty==='RSA');
  if(!jwk||!verify('RSA-SHA256',Buffer.from(`${parts[0]}.${parts[1]}`),createPublicKey({key:jwk,format:'jwk'}),Buffer.from(parts[2],'base64url')))throw new Error('Invalid Firebase identity signature.');
  return {email:claims.email,uid:claims.sub};
}
