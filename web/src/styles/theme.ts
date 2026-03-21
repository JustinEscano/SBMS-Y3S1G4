/**
 * Shared inline style tokens for the Orbit dark theme.
 * Used across all pages to ensure consistent design without Tailwind dependency.
 */

export const colors = {
    bg: '#080b14',
    surface: '#0f172a',
    surface2: '#1e293b',
    border: '#1e293b',
    borderLight: '#334155',
    text: '#e2e8f0',
    textMuted: '#94a3b8',
    textDim: '#64748b',
    blue: '#60a5fa',
    emerald: '#34d399',
    red: '#f87171',
    amber: '#fbbf24',
};

export const card: React.CSSProperties = {
    background: '#0f172a',
    border: '1px solid #1e293b',
    borderRadius: '16px',
    padding: '24px',
    color: '#e2e8f0',
};

export const pageHeader: React.CSSProperties = {
    marginBottom: '32px',
};

export const pageTitle: React.CSSProperties = {
    fontSize: '28px',
    fontWeight: 800,
    color: '#ffffff',
    margin: 0,
    letterSpacing: '-0.02em',
};

export const pageSub: React.CSSProperties = {
    fontSize: '14px',
    color: '#64748b',
    marginTop: '4px',
};

export const sectionTitle: React.CSSProperties = {
    fontSize: '16px',
    fontWeight: 700,
    color: '#ffffff',
    margin: '0 0 4px',
};

export const statsGrid: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '16px',
    marginBottom: '32px',
};

export const btn = (variant: 'primary' | 'danger' | 'ghost' = 'primary'): React.CSSProperties => ({
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    padding: '10px 18px',
    borderRadius: '10px',
    fontSize: '14px',
    fontWeight: 600,
    cursor: 'pointer',
    border: 'none',
    transition: 'all 0.15s ease',
    ...(variant === 'primary' ? {
        background: '#3b82f6',
        color: '#ffffff',
    } : variant === 'danger' ? {
        background: 'rgba(239,68,68,0.15)',
        color: '#f87171',
        border: '1px solid rgba(239,68,68,0.25)',
    } : {
        background: '#1e293b',
        color: '#e2e8f0',
        border: '1px solid #334155',
    }),
});

export const inputStyle: React.CSSProperties = {
    padding: '10px 14px',
    borderRadius: '10px',
    border: '1px solid #1e293b',
    background: '#0f172a',
    color: '#e2e8f0',
    fontSize: '14px',
    outline: 'none',
    width: '100%',
};

export const tableContainer: React.CSSProperties = {
    background: '#0f172a',
    border: '1px solid #1e293b',
    borderRadius: '16px',
    overflow: 'hidden',
};

export const tableHeader: React.CSSProperties = {
    background: '#080b14',
    borderBottom: '1px solid #1e293b',
};

export const th: React.CSSProperties = {
    padding: '14px 20px',
    textAlign: 'left' as const,
    fontSize: '12px',
    fontWeight: 600,
    color: '#64748b',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.06em',
};

export const td: React.CSSProperties = {
    padding: '16px 20px',
    fontSize: '14px',
    color: '#e2e8f0',
    borderBottom: '1px solid #0f172a',
};

export const trStyle: React.CSSProperties = {
    background: '#0f172a',
    transition: 'background 0.15s',
};
