import os
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor

OUTPUT_PATHS = [
    "public/submission/writeup.pdf",
    "output/pdf/Apex-Resolve-Writeup.pdf"
]

def draw_header(c, title, page_num):
    # Dark header background
    c.setFillColor(HexColor("#172629"))
    c.rect(0, 700, 595, 142, fill=True, stroke=False)
    
    # Accent eyebrow
    c.setFillColor(HexColor("#FFAD79"))
    c.setFont("Helvetica-Bold", 11)
    c.drawString(54, 800, "APEX RESOLVE  ·  HACKATHON WRITE-UP")
    
    # Main hero title
    c.setFillColor(HexColor("#F3F4EF"))
    c.setFont("Helvetica-Bold", 26)
    c.drawString(54, 760, title)
    
    # Subtitle
    c.setFillColor(HexColor("#ADB8B7"))
    c.setFont("Helvetica", 11)
    c.drawString(54, 736, "From real-time conversation to independently verified resolution")
    
    # Footer
    c.setFillColor(HexColor("#ADB8B7"))
    c.setFont("Helvetica", 9)
    c.drawString(54, 34, "Workplace Collaboration & Productivity Track  |  Nexconn Build Challenge 2026")
    c.drawRightString(541, 34, f"Page {page_num} of 2")
    c.setStrokeColor(HexColor("#344042"))
    c.setLineWidth(0.5)
    c.line(54, 48, 541, 48)

def draw_section(c, x, y, title, body_lines):
    c.setFillColor(HexColor("#D97736"))
    c.setFont("Helvetica-Bold", 13)
    c.drawString(x, y, title)
    
    c.setFillColor(HexColor("#202729"))
    c.setFont("Helvetica", 9.5)
    line_y = y - 16
    for line in body_lines:
        c.drawString(x, line_y, line)
        line_y -= 14
    return line_y - 8

def generate_pdf():
    os.makedirs("public/submission", exist_ok=True)
    os.makedirs("output/pdf", exist_ok=True)
    
    for path in OUTPUT_PATHS:
        c = canvas.Canvas(path, pagesize=A4)
        c.setTitle("Apex Resolve | Hackathon Write-up")
        c.setAuthor("Apex Resolve Team")
        
        # ================= PAGE 1 =================
        # Background
        c.setFillColor(HexColor("#FBFBF9"))
        c.rect(0, 0, 595, 842, fill=True, stroke=False)
        
        draw_header(c, "The Customer Problem & Solution", 1)
        
        y = 665
        y = draw_section(c, 54, y, "1. The Customer Problem", [
            "Support and engineering teams constantly lose track of bugs reported in live chat channels.",
            "A client complains in messaging, an engineer claims it is fixed, but no one knows what failed,",
            "who was affected, what proof was attached, or whether an independent teammate actually verified it.",
            "Traditional ticket trackers sever the fix from the original conversation that informed it."
        ])
        
        y = draw_section(c, 54, y, "2. One Report, One Verifiable Record", [
            "Apex Resolve transforms any Nexconn chat message into a dedicated, trackable resolution room.",
            "The source link travels permanently with the issue. Affected users, the reporter, and the assigned",
            "resolver maintain clear roles. ProofGuard AI inspects evidence logs before an authorized reviewer",
            "signs off, and the entire audit trail remains linked back to the original messaging context."
        ])
        
        y = draw_section(c, 54, y, "3. Enforced Separation of Duties", [
            "Supabase database triggers and Row-Level Security enforce strict role boundaries at the data layer:",
            "• Resolvers, reporters, and evidence uploaders are cryptographically prevented from self-approving.",
            "• Only authorized independent reviewers can issue binding verification approvals.",
            "• ProofGuard evaluates logs and flags missing verification steps with user consent."
        ])
        
        y = draw_section(c, 54, y, "4. 100% Native Mobile App with Offline-First Cache", [
            "Cross-platform Flutter mobile client (Android & iOS) designed for real-world resilience:",
            "• Local SQLite cache persists conversation history, contacts, and resolutions on device.",
            "• WhatsApp-style offline readability: Users can open the mobile app without internet connectivity",
            "  and immediately browse previously sent messages, evidence notes, and resolution history.",
            "• Automatic real-time synchronization via Nexconn WebSockets upon network reconnection."
        ])
        
        c.showPage()
        
        # ================= PAGE 2 =================
        c.setFillColor(HexColor("#FBFBF9"))
        c.rect(0, 0, 595, 842, fill=True, stroke=False)
        
        draw_header(c, "Architecture & Verification Proof", 2)
        
        y = 665
        y = draw_section(c, 54, y, "5. Nexconn Integration & Technical Architecture", [
            "• Chat SDK & UI: Powers 1:1 private messaging, community channels, and issue rooms.",
            "• Server-Signed Webhooks: Cryptographic SHA-1 signature verification on all chat events.",
            "• Hybrid Stack: Next.js 16 Web Workspace, Flutter Native Mobile, Supabase PostgreSQL, and",
            "  Firebase Auth with automated session minting and cross-platform authentication bypass."
        ])
        
        y = draw_section(c, 54, y, "6. Testing & Acceptance Verification", [
            "• 29/29 Node.js & Supabase security/protocol unit tests passing.",
            "• 14/14 Flutter mobile widget, serialization, and offline vault tests passing.",
            "• Production builds verified on live Vercel deployment with zero critical audit issues."
        ])
        
        y = draw_section(c, 54, y, "7. Live Downloads & Submission Deliverables", [
            "• Live Web App & Downloads Hub: https://apex-resolve-one.vercel.app/download",
            "• Native Android APK: https://apex-resolve-one.vercel.app/downloads/apex-resolve.apk",
            "• iOS Simulator Package: https://apex-resolve-one.vercel.app/downloads/apex-resolve-ios.zip",
            "• GitHub Repository: https://github.com/hemant12578/apex-resolve"
        ])
        
        # Highlight Box: Nexconn App Key & Judge Credentials
        c.setFillColor(HexColor("#172629"))
        c.roundRect(54, y - 5, 487, 85, 8, fill=True, stroke=False)
        
        c.setFillColor(HexColor("#FFAD79"))
        c.setFont("Helvetica-Bold", 10.5)
        c.drawString(70, y + 58, "OFFICIAL NEXCONN APP KEY FOR ORGANIZER VERIFICATION")
        
        c.setFillColor(HexColor("#FFFFFF"))
        c.setFont("Courier-Bold", 13)
        c.drawString(70, y + 40, "pkfcgjstpvdd8")
        
        c.setFillColor(HexColor("#ADB8B7"))
        c.setFont("Helvetica", 9)
        c.drawString(70, y + 20, "Pre-verified Judge Account: demo@apexresolve.com   |   Password: Password123!")
        c.drawString(70, y + 7, "Instant access to Web & Mobile clients with email verification bypass.")
        
        c.save()
        print(f"Generated {path} successfully.")

if __name__ == "__main__":
    generate_pdf()
