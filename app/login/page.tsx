import AuthPage, { type AuthSearchParams } from "@/components/AuthPage";
export const metadata = {title: "Sign in"};
export default function Login({searchParams}: {searchParams: AuthSearchParams}) {
  return <AuthPage mode="login" searchParams={searchParams}/>;
}
