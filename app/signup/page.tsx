import AuthPage, { type AuthSearchParams } from "@/components/AuthPage";
export const metadata = {title: "Create an account"};
export default function Signup({searchParams}: {searchParams: AuthSearchParams}) {
  return <AuthPage mode="signup" searchParams={searchParams}/>;
}
