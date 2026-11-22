import {cookies} from "next/headers";
import ThemeSwitch from "@/components/ThemeSwitch";
import type { Metadata } from "next";
import "./globals.css";
import FirebaseAnalytics from "@/components/FirebaseAnalytics";

export const metadata: Metadata = {
  title: { default: "Apex Resolve — From conversation to verified resolution", template: "%s · Apex Resolve" },
  description: "A collaborative workspace for resolving issues with a shared conversation, supporting evidence, and an authorized review.",
};

export default async function RootLayout({ children }: Readonly<{children: React.ReactNode}>) {
  const theme=(await cookies()).get("apex_theme")?.value==="white"?"white":"black";
  return <html lang="en" data-theme={theme}><body><ThemeSwitch initial={theme}/>{children}<FirebaseAnalytics/></body></html>;
}
