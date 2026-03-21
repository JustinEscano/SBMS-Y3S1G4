import React from "react";
import PageLayout from "./PageLayout";

const projectName = "Orbit - Smart Building Management Systems™";
const llm = "Llama-3.1-Claude";

const members = [
  { role: "Project Manager", name: "Escano, Justin Paul Louise C." },
  { role: "Lead Developer", name: "Denulan, Ace Philip S." },
  { role: "LLM Eng. / Backend Dev", name: "Estrada, Matthew Cymon S." },
  { role: "UI/UX Designer", name: "De Guzman, Gemerald" },
  { role: "Frontend Dev (Web/Mobile)", name: "Pagasartonga, Peter R." },
  { role: "Frontend Dev (Web)", name: "Sandino, Shierwin Carl" },
  { role: "LLM Engineer", name: "Manaloto, David Paul" },
  { role: "Backend Developer", name: "Villegas, Brian Isaac" },
  { role: "Frontend Dev (Web/Mobile)", name: "Posadas, Xander" },
];

const AboutPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "About" }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '32px', maxWidth: '1000px', margin: '0 auto' }}>
        
        <div style={{ textAlign: 'center', marginBottom: '16px', position: 'relative' }}>
          <div style={{ position: 'absolute', top: -50, left: '50%', transform: 'translateX(-50%)', width: '300px', height: '300px', borderRadius: '50%', background: '#3b82f6', opacity: 0.05, filter: 'blur(50px)', pointerEvents: 'none' }} />
          <h1 style={{ fontSize: '36px', fontWeight: 800, color: '#ffffff', margin: '0 0 16px', letterSpacing: '-0.02em', position: 'relative' }}>About Orbit</h1>
          <p style={{ fontSize: '16px', color: '#94a3b8', lineHeight: 1.6, maxWidth: '800px', margin: '0 auto', position: 'relative' }}>
            {projectName} is a smart platform that monitors room security, energy, and maintenance requests 
            to automate building operations and make facilities more efficient and comfortable. 
            It uses AI for energy optimization, device diagnostics, and room analysis based on real-time data, 
            letting users monitor everything from a web or mobile app. By simulating IoT devices, 
            Orbit cuts costs, prevents breakdowns, and improves daily life for occupants through 
            simple, secure controls.
          </p>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '24px' }}>
          
          <div style={{ flex: '1 1 300px', background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '32px', position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -20, right: -20, width: '150px', height: '150px', borderRadius: '50%', background: '#8b5cf6', opacity: 0.05, filter: 'blur(30px)', pointerEvents: 'none' }} />
            <h3 style={{ fontSize: '20px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px', position: 'relative' }}>AI Engine</h3>
            <p style={{ fontSize: '15px', color: '#94a3b8', lineHeight: 1.6, marginBottom: '24px', position: 'relative' }}>
              Orbit is powered by state-of-the-art Large Language Models to provide intelligent insights, 
              predictive maintenance, and automated anomaly detection.
            </p>
            <span style={{ display: 'inline-block', padding: '6px 14px', background: 'rgba(139,92,246,0.1)', border: '1px solid rgba(139,92,246,0.2)', color: '#c4b5fd', borderRadius: '8px', fontSize: '14px', fontWeight: 600, position: 'relative' }}>
              {llm}
            </span>
          </div>

          <div style={{ flex: '2 1 500px', background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '32px', position: 'relative', overflow: 'hidden' }}>
            <h3 style={{ fontSize: '20px', fontWeight: 700, color: '#ffffff', margin: '0 0 24px', position: 'relative' }}>Core Team</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '20px', position: 'relative' }}>
              {members.map((member, idx) => (
                <div key={idx} style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{ fontSize: '12px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '4px' }}>{member.role}</span>
                  <span style={{ fontSize: '15px', fontWeight: 500, color: '#e2e8f0' }}>{member.name}</span>
                </div>
              ))}
            </div>
          </div>

        </div>

        <div style={{ textAlign: 'center', marginTop: '24px', paddingTop: '32px', borderTop: '1px solid #1e293b', color: '#64748b', fontSize: '13px', lineHeight: 1.6 }}>
          <p style={{ margin: 0 }}>
            This app is a registered trademark of {projectName}.<br />
            Use of this platform is subject to our <a href="/terms" style={{ color: '#3b82f6', textDecoration: 'none' }}>Terms of Service</a> and <a href="/privacy" style={{ color: '#3b82f6', textDecoration: 'none' }}>Privacy Policy</a>.
          </p>
        </div>

      </div>
    </PageLayout>
  );
};

export default AboutPage;