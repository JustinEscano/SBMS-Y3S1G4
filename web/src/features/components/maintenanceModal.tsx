import React, { useEffect, useState } from "react";
import type { MaintenanceRequest, Equipment, User } from "../types/dashboardTypes";
import { parseComments } from "../utils/comments";

export type MaintenanceModalMode = "add" | "edit" | "delete";

interface MaintenanceModalProps {
  mode: MaintenanceModalMode;
  request?: MaintenanceRequest;
  equipments: Equipment[];
  users: User[];
  onClose: () => void;
  onSubmit: (data: Partial<MaintenanceRequest> & { id?: string; comments?: string; newAttachments?: File[] }) => Promise<MaintenanceRequest | void>;
}

const STATUS_OPTIONS: MaintenanceRequest["status"][] = ["pending", "in_progress", "resolved"];

/* ── shared style tokens ── */
const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.65)',
    backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', zIndex: 9999, padding: '20px',
  },
  card: {
    background: '#141828', border: '1px solid #1d2540', borderRadius: '20px',
    width: '100%', maxWidth: '560px', overflow: 'hidden',
    boxShadow: '0 24px 64px rgba(0,0,0,0.5)', maxHeight: '92vh', display: 'flex', flexDirection: 'column' as const,
  },
  header: {
    background: '#0d1022', borderBottom: '1px solid #1d2540',
    padding: '20px 24px', display: 'flex', alignItems: 'center',
    justifyContent: 'space-between', flexShrink: 0,
  },
  title: { fontSize: '16px', fontWeight: 700, color: '#f8fafc', margin: 0 },
  closeBtn: { background: 'transparent', border: 'none', color: '#64748b', fontSize: '20px', cursor: 'pointer', lineHeight: 1, padding: '2px 6px', borderRadius: '6px' },
  body: { padding: '24px', overflowY: 'auto' as const, flex: 1 },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' },
  fieldWrap: { display: 'flex', flexDirection: 'column' as const, gap: '6px' },
  label: { fontSize: '11px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase' as const, letterSpacing: '0.06em' },
  input: { padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540', background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none', width: '100%', boxSizing: 'border-box' as const },
  select: { padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540', background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none', width: '100%', boxSizing: 'border-box' as const, cursor: 'pointer' },
  textarea: { padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540', background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none', width: '100%', boxSizing: 'border-box' as const, resize: 'vertical' as const, minHeight: '80px', fontFamily: 'inherit' },
  footer: { padding: '16px 24px', borderTop: '1px solid #1d2540', display: 'flex', gap: '10px', flexShrink: 0 },
  btnPrimary: { padding: '10px 22px', borderRadius: '10px', border: 'none', background: '#5b81fb', color: '#fff', fontSize: '14px', fontWeight: 600, cursor: 'pointer' },
  btnCancel: { padding: '10px 22px', borderRadius: '10px', border: '1px solid #334155', background: '#1e293b', color: '#e2e8f0', fontSize: '14px', fontWeight: 600, cursor: 'pointer' },
  btnDanger: { padding: '10px 22px', borderRadius: '10px', border: '1px solid rgba(239,68,68,0.35)', background: 'rgba(239,68,68,0.12)', color: '#f87171', fontSize: '14px', fontWeight: 600, cursor: 'pointer' },
  btnSecondary: { padding: '10px 22px', borderRadius: '10px', border: '1px solid #1d2540', background: 'transparent', color: '#94a3b8', fontSize: '14px', fontWeight: 600, cursor: 'pointer' },
};

const statusLabel = (s: string) => s === 'in_progress' ? 'In Progress' : s.charAt(0).toUpperCase() + s.slice(1);

const MaintenanceModal: React.FC<MaintenanceModalProps> = ({ mode, request, equipments, users, onClose, onSubmit }) => {
  const [page, setPage] = useState<1 | 2>(1);
  const [formData, setFormData] = useState({
    user: "", equipment: "", issue: "",
    status: "pending" as MaintenanceRequest["status"],
    scheduled_date: "", resolved_at: "", assigned_to: "",
  });
  const [initialComments, setInitialComments] = useState("");
  const [attachments, setAttachments] = useState<File[]>([]);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && request) {
      setFormData({
        user: request.user || "", equipment: request.equipment || "",
        issue: request.issue || "", status: request.status || "pending",
        scheduled_date: request.scheduled_date ? request.scheduled_date.split("T")[0] : "",
        resolved_at: request.resolved_at ? request.resolved_at.replace("Z", "") : "",
        assigned_to: request.assigned_to || "",
      });
    } else if (mode === "add") {
      setFormData({ user: "", equipment: "", issue: "", status: "pending", scheduled_date: "", resolved_at: "", assigned_to: "" });
      setInitialComments(""); setAttachments([]); setPage(1);
    }
  }, [mode, request]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async () => {
    if (submitting) return;
    setSubmitting(true);
    try {
      let finalComments = initialComments;
      if (mode === "add" && initialComments.trim()) {
        const now = new Date().toLocaleString();
        finalComments = `\n[${now}] System (Auto): Request created - ${initialComments}`;
      }
      await onSubmit({
        ...formData,
        comments: finalComments || undefined,
        id: request?.id,
        newAttachments: attachments,
        resolved_at: formData.resolved_at ? new Date(formData.resolved_at).toISOString() : undefined,
        assigned_to: formData.assigned_to || undefined,
      });
      onClose();
    } catch (err) { console.error(err); }
    finally { setSubmitting(false); }
  };

  const getUser = (id?: string) => users.find(u => u.id === id)?.username || "-";
  const getEquipment = (id?: string) => equipments.find(e => e.id === id)?.name || "-";

  const title = mode === "add" ? "Add Maintenance Request" : mode === "edit" ? "Edit Maintenance Request" : "Delete Maintenance Request";

  // Step indicator for add wizard
  const StepIndicator = () => (
    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      {[1, 2].map(n => (
        <div key={n} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ width: '24px', height: '24px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', fontWeight: 700, background: page >= n ? '#5b81fb' : '#1e293b', color: page >= n ? '#fff' : '#64748b', border: page >= n ? 'none' : '1px solid #334155' }}>{n}</div>
          <span style={{ fontSize: '12px', color: page === n ? '#f8fafc' : '#64748b', fontWeight: page === n ? 600 : 400 }}>{n === 1 ? 'Details' : 'Attachments'}</span>
          {n < 2 && <div style={{ width: '24px', height: '1px', background: '#1d2540' }} />}
        </div>
      ))}
    </div>
  );

  return (
    <div style={S.backdrop} onClick={onClose}>
      <div style={S.card} onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div style={S.header}>
          <h2 style={S.title}>{title}</h2>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>
        {mode === "add" && (
          <div style={{ padding: '12px 24px', borderBottom: '1px solid #1d2540', background: '#0d1022' }}>
            <StepIndicator />
          </div>
        )}

        {/* Delete */}
        {mode === "delete" && request ? (
          <>
            <div style={{ padding: '32px 24px', textAlign: 'center' }}>
              <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: '24px' }}>🗑</div>
              <p style={{ color: '#e2e8f0', fontSize: '15px', marginBottom: '6px', fontWeight: 600 }}>Delete this maintenance request?</p>
              <p style={{ color: '#64748b', fontSize: '13px', margin: 0 }}>
                Equipment: <strong style={{ color: '#94a3b8' }}>{getEquipment(request.equipment)}</strong> — Reported by <strong style={{ color: '#94a3b8' }}>{getUser(request.user)}</strong>
              </p>
            </div>
            <div style={{ ...S.footer, justifyContent: 'flex-end' }}>
              <button style={S.btnCancel} onClick={onClose}>Cancel</button>
              <button style={S.btnDanger} onClick={handleSubmit} disabled={submitting}>{submitting ? "Deleting..." : "Delete Request"}</button>
            </div>
          </>
        ) : (
          <>
            <div style={S.body}>
              {/* Add — Page 1 */}
              {mode === "add" && page === 1 && (
                <>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Equipment</label>
                    <select style={S.select} name="equipment" value={formData.equipment} onChange={handleChange} required>
                      <option value="">Select Equipment</option>
                      {equipments.map(eq => <option key={eq.id} value={eq.id} style={{ background: '#0a0e1a' }}>{eq.name}</option>)}
                    </select>
                  </div>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Reported By</label>
                    <select style={S.select} name="user" value={formData.user} onChange={handleChange} required>
                      <option value="">Select User</option>
                      {users.map(u => <option key={u.id} value={u.id} style={{ background: '#0a0e1a' }}>{u.username || "Unknown User"}</option>)}
                    </select>
                  </div>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Issue Description</label>
                    <textarea style={S.textarea} name="issue" value={formData.issue} onChange={handleChange} placeholder="Describe the issue..." required />
                  </div>
                  <div style={{ ...S.grid2, marginBottom: '16px' }}>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Status</label>
                      <select style={S.select} name="status" value={formData.status} onChange={handleChange} required>
                        {STATUS_OPTIONS.map(s => <option key={s} value={s} style={{ background: '#0a0e1a' }}>{statusLabel(s)}</option>)}
                      </select>
                    </div>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Scheduled Date</label>
                      <input style={S.input} type="date" name="scheduled_date" value={formData.scheduled_date} onChange={handleChange} />
                    </div>
                  </div>
                </>
              )}
              {/* Add — Page 2 */}
              {mode === "add" && page === 2 && (
                <>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Assigned To</label>
                    <select style={S.select} name="assigned_to" value={formData.assigned_to} onChange={handleChange}>
                      <option value="">Select Assignee</option>
                      {users.map(u => <option key={u.id} value={u.id} style={{ background: '#0a0e1a' }}>{u.username || "Unknown User"}</option>)}
                    </select>
                  </div>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Initial Notes</label>
                    <textarea style={S.textarea} value={initialComments} onChange={e => setInitialComments(e.target.value)} placeholder="Add initial notes (will be logged on creation)..." rows={3} />
                  </div>
                  <div style={S.fieldWrap}>
                    <label style={S.label}>Attachments</label>
                    <label style={{ ...S.btnCancel, display: 'inline-block', cursor: 'pointer', textAlign: 'center', padding: '10px 14px' }}>
                      📎 Choose Files
                      <input type="file" multiple style={{ display: 'none' }} onChange={e => e.target.files && setAttachments(prev => [...prev, ...Array.from(e.target.files as FileList)])} />
                    </label>
                    {attachments.length > 0 && (
                      <div style={{ marginTop: '8px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        {attachments.map((f, i) => <span key={i} style={{ fontSize: '12px', color: '#94a3b8', background: '#0d1022', padding: '4px 10px', borderRadius: '6px' }}>📄 {f.name}</span>)}
                      </div>
                    )}
                  </div>
                </>
              )}
              {/* Edit */}
              {mode === "edit" && request && (
                <>
                  <div style={{ ...S.grid2, marginBottom: '16px' }}>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Equipment</label>
                      <select style={S.select} name="equipment" value={formData.equipment} onChange={handleChange}>
                        <option value="">Select Equipment</option>
                        {equipments.map(eq => <option key={eq.id} value={eq.id} style={{ background: '#0a0e1a' }}>{eq.name}</option>)}
                      </select>
                    </div>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Reported By</label>
                      <select style={S.select} name="user" value={formData.user} onChange={handleChange}>
                        <option value="">Select User</option>
                        {users.map(u => <option key={u.id} value={u.id} style={{ background: '#0a0e1a' }}>{u.username || "Unknown User"}</option>)}
                      </select>
                    </div>
                  </div>
                  <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                    <label style={S.label}>Issue Description</label>
                    <textarea style={S.textarea} name="issue" value={formData.issue} onChange={handleChange} />
                  </div>
                  <div style={{ ...S.grid2, marginBottom: '16px' }}>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Status</label>
                      <select style={S.select} name="status" value={formData.status} onChange={handleChange}>
                        {STATUS_OPTIONS.map(s => <option key={s} value={s} style={{ background: '#0a0e1a' }}>{statusLabel(s)}</option>)}
                      </select>
                    </div>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Assigned To</label>
                      <select style={S.select} name="assigned_to" value={formData.assigned_to} onChange={handleChange}>
                        <option value="">Unassigned</option>
                        {users.map(u => <option key={u.id} value={u.id} style={{ background: '#0a0e1a' }}>{u.username}</option>)}
                      </select>
                    </div>
                  </div>
                  <div style={{ ...S.grid2, marginBottom: '16px' }}>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Scheduled Date</label>
                      <input style={S.input} type="date" name="scheduled_date" value={formData.scheduled_date} onChange={handleChange} />
                    </div>
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Resolved At</label>
                      <input style={S.input} type="datetime-local" name="resolved_at" value={formData.resolved_at} onChange={handleChange} />
                    </div>
                  </div>
                  {/* Comments history */}
                  {parseComments(request.comments).length > 0 && (
                    <div style={S.fieldWrap}>
                      <label style={S.label}>Comments History</label>
                      <div style={{ background: '#0d1022', border: '1px solid #1d2540', borderRadius: '10px', padding: '12px', maxHeight: '160px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                        {parseComments(request.comments).map((entry, index) => (
                          <div key={index}>
                            <p style={{ fontSize: '11px', color: '#5b81fb', margin: '0 0 2px', fontWeight: 600 }}>[{entry.timestamp}] {entry.user} ({entry.role})</p>
                            <p style={{ fontSize: '13px', color: '#cbd5e1', margin: 0 }}>{entry.message}</p>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>
            <div style={S.footer}>
              {mode === "add" && page === 1 && (
                <>
                  <button style={S.btnCancel} onClick={onClose}>Cancel</button>
                  <button style={{ ...S.btnPrimary, marginLeft: 'auto' }} onClick={() => setPage(2)}>Next →</button>
                </>
              )}
              {mode === "add" && page === 2 && (
                <>
                  <button style={S.btnSecondary} onClick={() => setPage(1)}>← Back</button>
                  <button style={{ ...S.btnPrimary, marginLeft: 'auto' }} onClick={handleSubmit} disabled={submitting}>{submitting ? "Submitting..." : "Submit Request"}</button>
                </>
              )}
              {mode === "edit" && (
                <>
                  <button style={S.btnCancel} onClick={onClose}>Cancel</button>
                  <button style={{ ...S.btnPrimary, marginLeft: 'auto' }} onClick={handleSubmit} disabled={submitting}>{submitting ? "Saving..." : "Save Changes"}</button>
                </>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default MaintenanceModal;