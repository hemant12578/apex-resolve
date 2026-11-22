import Link from "next/link";
import Brand from "@/components/Brand";
import { 
  Smartphone, 
  Apple, 
  Github, 
  ExternalLink, 
  Key, 
  Terminal, 
  CheckCircle2, 
  WifiOff, 
  ShieldCheck, 
  MessageSquare,
  ArrowDownToLine,
  Zap
} from "lucide-react";

export const metadata = {
  title: "Download Apex Resolve Mobile Apps (Android & iOS)",
  description: "Download the native Android APK and iOS Simulator build for Apex Resolve, view test credentials, and inspect source code."
};

export default function DownloadPage() {
  return (
    <div className="landing min-h-screen flex flex-col justify-between">
      <header className="public-nav wrap">
        <Brand />
        <nav aria-label="Main navigation" className="flex items-center gap-6">
          <Link href="/" className="login-link">Web App</Link>
          <a 
            href="https://github.com/hemant12578/apex-resolve" 
            target="_blank" 
            rel="noopener noreferrer" 
            className="login-link flex items-center gap-1.5"
          >
            <Github size={16} />
            GitHub
          </a>
        </nav>
        <div className="nav-actions">
          <Link className="login-link" href="/login">Sign in</Link>
          <Link className="btn btn-primary nav-cta" href="/signup">Get started</Link>
        </div>
      </header>

      <main className="wrap py-12 flex-1">
        {/* Hero Section */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="eyebrow justify-center mb-3">
            <span className="signal-line" />
            Competition Submission &amp; Reviewer Hub
            <span className="signal-line" />
          </div>
          <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-4 text-[#f3f4ef]">
            Apex Resolve <span className="text-[#ffad79]">Mobile</span>
          </h1>
          <p className="text-lg md:text-xl text-[#adb8b7] leading-relaxed">
            Native cross-platform Flutter mobile client for communication and verified issue resolution.
            Features offline message viewing, dual Firebase &amp; Supabase auth, and real-time chat.
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4 mt-8">
            <a 
              href="/downloads/apex-resolve.apk" 
              download="apex-resolve.apk" 
              className="btn btn-primary text-base font-semibold px-6 py-3 shadow-lg shadow-orange-950/30 hover:scale-[1.02] transition-transform"
            >
              <Smartphone size={19} />
              Download Android APK
            </a>
            <a 
              href="/downloads/apex-resolve-ios.zip" 
              download="apex-resolve-ios.zip" 
              className="btn btn-outline text-base font-semibold px-6 py-3 hover:scale-[1.02] transition-transform"
            >
              <Apple size={19} />
              Download iOS Bundle
            </a>
            <a 
              href="https://github.com/hemant12578/apex-resolve" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="btn text-base font-semibold px-6 py-3 border-[#344042] text-[#f3f4ef] hover:bg-[#232c2e]"
            >
              <Github size={19} />
              GitHub Repository
            </a>
          </div>
        </div>

        {/* Judge & Reviewer Credentials Banner */}
        <div className="mb-14 rounded-2xl border border-[#ffad79]/40 bg-gradient-to-r from-[#171e20] via-[#202729] to-[#171e20] p-6 md:p-8 shadow-xl relative overflow-hidden">
          <div className="absolute top-0 right-0 transform translate-x-8 -translate-y-8 w-44 h-44 bg-[#ffad79]/10 rounded-full blur-3xl pointer-events-none" />
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6 relative z-10">
            <div>
              <div className="flex items-center gap-2 text-[#ffad79] font-mono text-sm tracking-wide uppercase mb-1">
                <Key size={16} />
                <span>Verified Judge &amp; Tester Accounts</span>
              </div>
              <h2 className="text-2xl font-bold text-[#f3f4ef] mb-2">Instant Test Access (No Signup Required)</h2>
              <p className="text-[#adb8b7] text-sm max-w-xl">
                Pre-configured test accounts with bypass credentials for quick evaluation on both web and mobile:
              </p>
            </div>
            <div className="flex flex-col sm:flex-row gap-4 w-full md:w-auto">
              <div className="bg-[#101618] border border-[#344042] rounded-xl p-4 min-w-[240px]">
                <span className="text-xs font-mono text-[#ffad79] uppercase block mb-1">Primary Judge Account</span>
                <div className="font-mono text-sm text-[#f3f4ef] select-all font-semibold">demo@apexresolve.com</div>
                <div className="font-mono text-xs text-[#adb8b7] mt-1 select-all">Password: <span className="text-[#f3f4ef]">Password123!</span></div>
              </div>
              <div className="bg-[#101618] border border-[#344042] rounded-xl p-4 min-w-[240px]">
                <span className="text-xs font-mono text-[#adb8b7] uppercase block mb-1">Secondary Tester Account</span>
                <div className="font-mono text-sm text-[#f3f4ef] select-all font-semibold">test@apexresolve.com</div>
                <div className="font-mono text-xs text-[#adb8b7] mt-1 select-all">Password: <span className="text-[#f3f4ef]">Password123!</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* Download & Installation Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
          {/* Android Card */}
          <div className="rounded-2xl border border-[#344042] bg-[#171e20] p-6 md:p-8 flex flex-col justify-between hover:border-[#ffad79]/40 transition-colors">
            <div>
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
                    <Smartphone size={26} />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-[#f3f4ef]">Android Package</h3>
                    <span className="text-xs text-[#adb8b7]">apex-resolve.apk</span>
                  </div>
                </div>
                <span className="text-xs font-mono px-2.5 py-1 rounded-full bg-[#101618] text-emerald-400 border border-emerald-500/30">
                  Ready to install
                </span>
              </div>

              <p className="text-sm text-[#adb8b7] mb-6">
                Universal Android build compatible with Android 8.0+ devices and Android Studio emulators.
              </p>

              <div className="bg-[#101618] rounded-xl p-4 border border-[#273234] mb-6">
                <div className="text-xs font-mono uppercase tracking-wider text-[#adb8b7] mb-2 font-semibold">
                  How to install on Android:
                </div>
                <ol className="text-sm text-[#d4dbd8] space-y-2 list-decimal list-inside">
                  <li>Download the APK file directly to your Android device or PC.</li>
                  <li>Tap the APK to install (enable &quot;Install from unknown sources&quot; if prompted).</li>
                  <li>Or drag and drop the APK file onto any running Android Studio Emulator.</li>
                  <li>Launch Apex Resolve and sign in using the test credentials above.</li>
                </ol>
              </div>
            </div>

            <a 
              href="/downloads/apex-resolve.apk" 
              download="apex-resolve.apk" 
              className="btn btn-primary w-full py-3 font-semibold flex items-center justify-center gap-2"
            >
              <ArrowDownToLine size={18} />
              Download Android APK
            </a>
          </div>

          {/* iOS Card */}
          <div className="rounded-2xl border border-[#344042] bg-[#171e20] p-6 md:p-8 flex flex-col justify-between hover:border-[#ffad79]/40 transition-colors">
            <div>
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-sky-500/10 border border-sky-500/20 flex items-center justify-center text-sky-400">
                    <Apple size={26} />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-[#f3f4ef]">iOS Simulator Build</h3>
                    <span className="text-xs text-[#adb8b7]">apex-resolve-ios.zip</span>
                  </div>
                </div>
                <span className="text-xs font-mono px-2.5 py-1 rounded-full bg-[#101618] text-sky-400 border border-sky-500/30">
                  Simulator bundle
                </span>
              </div>

              <p className="text-sm text-[#adb8b7] mb-6">
                Packaged <code className="text-[#ffad79] text-xs">Runner.app</code> for macOS Xcode iOS Simulators (iPhone 16 / iOS 17+).
              </p>

              <div className="bg-[#101618] rounded-xl p-4 border border-[#273234] mb-6">
                <div className="text-xs font-mono uppercase tracking-wider text-[#adb8b7] mb-2 font-semibold">
                  How to install on Mac iOS Simulator:
                </div>
                <ol className="text-sm text-[#d4dbd8] space-y-2 list-decimal list-inside">
                  <li>Download and unzip <code className="text-[#ffad79] text-xs">apex-resolve-ios.zip</code> to get <code className="text-[#ffad79] text-xs">Runner.app</code>.</li>
                  <li>Open Xcode Simulator (or run <code className="text-[#ffad79] text-xs">open -a Simulator</code>).</li>
                  <li>Drag and drop <code className="text-[#ffad79] text-xs">Runner.app</code> directly onto the booted simulator window.</li>
                  <li>Or run in Mac terminal: <br/><code className="text-xs font-mono text-[#ffad79] bg-[#171e20] px-2 py-0.5 rounded inline-block mt-1">xcrun simctl install booted Runner.app</code></li>
                </ol>
              </div>
            </div>

            <a 
              href="/downloads/apex-resolve-ios.zip" 
              download="apex-resolve-ios.zip" 
              className="btn btn-outline w-full py-3 font-semibold flex items-center justify-center gap-2 border-[#52605f] text-[#f3f4ef] hover:border-[#ffad79]"
            >
              <ArrowDownToLine size={18} />
              Download iOS Simulator ZIP
            </a>
          </div>
        </div>

        {/* Local Run Instructions for Judges */}
        <div className="rounded-2xl border border-[#344042] bg-[#171e20] p-6 md:p-8 mb-16">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-lg bg-[#ffad79]/10 border border-[#ffad79]/20 flex items-center justify-center text-[#ffad79]">
              <Terminal size={22} />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-[#f3f4ef]">Run Locally from Terminal</h2>
              <p className="text-sm text-[#adb8b7]">Quick start commands for Mac / Linux developers and reviewers</p>
            </div>
          </div>

          <div className="bg-[#101618] rounded-xl p-5 border border-[#273234] font-mono text-sm text-[#f3f4ef] overflow-x-auto space-y-3">
            <div className="text-[#adb8b7]"># 1. Clone the repository</div>
            <div className="text-emerald-400">git clone https://github.com/hemant12578/apex-resolve.git</div>
            
            <div className="text-[#adb8b7] pt-2"># 2. Navigate to the mobile app directory</div>
            <div className="text-emerald-400">cd apex-resolve/mobile</div>
            
            <div className="text-[#adb8b7] pt-2"># 3. Fetch Flutter dependencies</div>
            <div className="text-emerald-400">flutter pub get</div>
            
            <div className="text-[#adb8b7] pt-2"># 4. Launch on your connected iOS simulator, Android device, or emulator</div>
            <div className="text-emerald-400">flutter run</div>
          </div>
        </div>

        {/* Highlight Architecture & Offline Capabilities */}
        <div className="mb-12">
          <h2 className="text-2xl font-bold text-[#f3f4ef] mb-6 text-center">Mobile Architecture &amp; Key Features</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="rounded-xl border border-[#273234] bg-[#171e20] p-6">
              <div className="text-[#ffad79] mb-3"><WifiOff size={26} /></div>
              <h3 className="text-lg font-bold text-[#f3f4ef] mb-2">Offline Cache &amp; Storage</h3>
              <p className="text-sm text-[#adb8b7] leading-relaxed">
                Local SQLite cache and persistent message history. Users can open the mobile app without internet connectivity to review older conversations, evidence records, and resolutions (WhatsApp-style offline readability).
              </p>
            </div>

            <div className="rounded-xl border border-[#273234] bg-[#171e20] p-6">
              <div className="text-[#ffad79] mb-3"><Zap size={26} /></div>
              <h3 className="text-lg font-bold text-[#f3f4ef] mb-2">Real-time WebSocket Sync</h3>
              <p className="text-sm text-[#adb8b7] leading-relaxed">
                Powered by Nexconn IM Engine with instant message delivery, live room status updates, typing indicators, and seamless synchronization with the web workspace.
              </p>
            </div>

            <div className="rounded-xl border border-[#273234] bg-[#171e20] p-6">
              <div className="text-[#ffad79] mb-3"><ShieldCheck size={26} /></div>
              <h3 className="text-lg font-bold text-[#f3f4ef] mb-2">Verified Resolution Pipeline</h3>
              <p className="text-sm text-[#adb8b7] leading-relaxed">
                Integrated issue-to-resolution lifecycle: chat report → issue extraction → evidence verification → teammate approval signoff with full tamper-evident audit logs.
              </p>
            </div>
          </div>
        </div>
      </main>

      <footer className="public-footer wrap py-8 border-t border-[#344042] flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-[#adb8b7]">
        <Brand />
        <div className="flex items-center gap-6">
          <a href="https://github.com/hemant12578/apex-resolve" target="_blank" rel="noopener noreferrer" className="hover:text-[#ffad79] flex items-center gap-1">
            <Github size={16} /> GitHub
          </a>
          <Link href="/login" className="hover:text-[#ffad79]">Web Sign In</Link>
          <a href="#main" className="hover:text-[#ffad79]">Back to top</a>
        </div>
      </footer>
    </div>
  );
}
