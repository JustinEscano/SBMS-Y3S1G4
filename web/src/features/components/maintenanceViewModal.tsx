import React, { useState, useEffect, useRef } from "react";
import type { MaintenanceRequest, User, Attachment } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
import { userService } from "../services/userService";
import { parseComments } from "../utils/comments";

interface MaintenanceViewModalProps {
  request: MaintenanceRequest;
  users: User[];
  currentUser?: Partial<User> | null;
  onClose: () => void;
  onRefresh: () => void;
  updateRequest?: (id: string, data: Partial<MaintenanceRequest>) => Promise<MaintenanceRequest>;
}

/* ── shared style tokens ── */
const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.65)',
    backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', zIndex: 9999, padding: '20px',
  },
  modal: {
    background: '#141828', border: '1px solid #1d2540', borderRadius: '16px',
    width: '100%', maxWidth: '1000px', overflow: 'hidden',
    boxShadow: '0 24px 64px rgba(0,0,0,0.5)', display: 'flex', flexDirection: 'column' as const,
    maxHeight: '90vh',
  },
  header: {
    padding: '24px 32px 16px', display: 'flex', alignItems: 'center',
    justifyContent: 'space-between', flexShrink: 0,
  },
  title: { fontSize: '20px', fontWeight: 600, color: '#f8fafc', margin: 0 },
  body: {
    padding: '0 32px 32px', flex: 1, overflow: 'hidden',
    display: 'grid', gridTemplateColumns: 'minmax(250px, 1fr) 2fr minmax(300px, 1.2fr)', gap: '24px',
  },
  card: {
    background: '#1e253c', borderRadius: '12px', padding: '20px',
    display: 'flex', flexDirection: 'column' as const,
  },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#f8fafc', margin: '0 0 16px 0' },
  label: { fontSize: '13px', color: '#94a3b8', margin: '0 0 4px 0', fontWeight: 500 },
  value: { fontSize: '14px', color: '#f8fafc', margin: 0 },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' },
  avatar: { width: '32px', height: '32px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600, fontSize: '14px', flexShrink: 0 },
  iconRow: { display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' },
  icon: { fontSize: '16px', color: '#94a3b8', width: '20px', textAlign: 'center' as const },
  btnPrimary: { padding: '8px 16px', borderRadius: '8px', border: 'none', background: '#5b81fb', color: '#fff', fontSize: '13px', fontWeight: 600, cursor: 'pointer', transition: 'background 0.2s', width: '100%' },
  btnCancel: { padding: '8px 16px', borderRadius: '8px', border: '1px solid #334155', background: 'transparent', color: '#e2e8f0', fontSize: '13px', fontWeight: 600, cursor: 'pointer', transition: 'background 0.2s', textAlign: 'center' as const },
  textarea: {
    padding: '12px 16px', borderRadius: '8px', border: '1px solid #1d2540',
    background: '#0d1022', color: '#e2e8f0', fontSize: '13px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const, resize: 'none' as const,
    fontFamily: 'inherit',
  },
  select: {
    padding: '10px 12px', borderRadius: '8px', border: '1px solid #1d2540',
    background: '#0d1022', color: '#e2e8f0', fontSize: '13px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const, cursor: 'pointer',
    appearance: 'none' as const,
  },
  statusBadge: (status: string) => {
    switch(status) {
      case 'pending': return { color: '#f59e0b', fontWeight: 500 };
      case 'in_progress': return { color: '#3b82f6', fontWeight: 500 };
      case 'resolved': return { color: '#10b981', fontWeight: 500 };
      default: return { color: '#94a3b8', fontWeight: 500 };
    }
  }
};

const formatStatus = (s: string) => s === 'in_progress' ? 'In Progress' : s.charAt(0).toUpperCase() + s.slice(1);

const MaintenanceViewModal: React.FC<MaintenanceViewModalProps> = ({ request, users, currentUser, onClose, onRefresh, updateRequest }) => {
  if (!request) return null;

  const [reportedBy, setReportedBy] = useState<User | null>(null);
  const [assignedUser, setAssignedUser] = useState<User | null>(null);
  
  // Right Column input states
  const [newResponse, setNewResponse] = useState("");
  const [selectedAssignee, setSelectedAssignee] = useState<string>(request.assigned_to || "");
  
  const [attachments, setAttachments] = useState<Attachment[]>(request.attachments ?? []);
  const [previewAttachment, setPreviewAttachment] = useState<Attachment | null>(null);
  const [tempComments, setTempComments] = useState(request.comments || "");
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const commentsEndRef = useRef<HTMLDivElement>(null);

  const getFileSrc = (src: string): string => {
    if (!src) return "";
    if (src.startsWith("blob:") || /^https?:\/\//.test(src)) return src;
    return `${window.location.origin}${src.startsWith('/') ? '' : '/'}${src}`;
  };

  useEffect(() => {
    // Scroll to bottom of comments when they change
    commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [tempComments]);

  useEffect(() => {
    const fetchUsers = async () => {
      // Reporter
      if (request.user) {
        let rUser = users.find(u => u.id === request.user);
        if (!rUser && request.user !== currentUser?.id) {
          try { rUser = await userService.getById(request.user); } catch (e) {}
        }
        setReportedBy(rUser || (currentUser?.id === request.user ? currentUser as User : null));
      }
      // Assignee
      if (request.assigned_to) {
        let aUser = users.find(u => u.id === request.assigned_to);
        if (!aUser && request.assigned_to !== currentUser?.id) {
          try { aUser = await userService.getById(request.assigned_to); } catch (e) {}
        }
        setAssignedUser(aUser || (currentUser?.id === request.assigned_to ? currentUser as User : null));
        setSelectedAssignee(request.assigned_to);
      }
    };
    fetchUsers();
  }, [request.user, request.assigned_to, users, currentUser]);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (previewAttachment) setPreviewAttachment(null);
        else onClose();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [previewAttachment, onClose]);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !request.id || uploading) return;
    setUploading(true);
    const tempAtt: Attachment = { id: `temp-${Date.now()}`, file: URL.createObjectURL(file), file_name: file.name, maintenance_request: request.id, file_type: file.type, uploaded_at: new Date().toISOString() };
    setAttachments(p => [...p, tempAtt]);
    try {
      const realAtt = await maintenanceService.uploadAttachment(request.id, file, file.name);
      setAttachments(p => p.map(a => a.id === tempAtt.id ? realAtt : a));
      onRefresh();
    } catch (err) {
      setAttachments(p => p.filter(a => a.id !== tempAtt.id));
      console.error("Upload failed", err);
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const handleRespond = async () => {
    if (!newResponse.trim() || sending) return;
    setSending(true);
    const text = newResponse;
    const now = new Date().toLocaleString();
    const appendEntry = `\n[${now}] ${currentUser?.username || 'Unknown'} (${currentUser?.role || 'Admin'}): ${text}`;
    const optimistic = tempComments + appendEntry;
    setTempComments(optimistic);
    setNewResponse("");

    const respondPayload: { response: string, assigned_to?: string } = { response: text };
    
    // Only send assigned_to if it actually changed
    if (selectedAssignee && selectedAssignee !== request.assigned_to) {
       respondPayload.assigned_to = selectedAssignee;
       
       // Optimistically update assignment UI
       const newAssigneeData = users.find(u => u.id === selectedAssignee);
       if (newAssigneeData) {
         setAssignedUser(newAssigneeData);
       }
    }

    try {
      const updated = await maintenanceService.respond(request.id!, respondPayload);
      setTempComments(updated.comments || "");
      onRefresh(); // Refresh parent to get real update
    } catch (e) {
      setTempComments(request.comments || ""); // rollback
      setNewResponse(text); // restore draft
      console.error("Failed to send response", e);
    } finally {
      setSending(false);
    }
  };

  const parsedComments = parseComments(tempComments);
  const isImage = (type: string) => type.startsWith('image/');
  const assigneeInitial = (assignedUser?.username || 'U').charAt(0).toUpperCase();

  return (
    <>
      <div style={S.backdrop} onClick={onClose}>
        <div style={S.modal} onClick={e => e.stopPropagation()}>
          <div style={S.header}>
            <h2 style={S.title}><span style={{ color: '#64748b', marginRight: '8px', cursor: 'pointer' }} onClick={onClose}>&lt;</span> Maintenance request</h2>
          </div>

          <div style={S.body}>
            {/* LEFT COLUMN: Details & Assigned */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', overflowY: 'auto' }}>
              <div style={S.card}>
                <h3 style={S.cardTitle}>Details</h3>
                <div style={S.grid2}>
                  <div>
                    <p style={S.label}>Status:</p>
                    <p style={{ ...S.value, ...S.statusBadge(request.status) }}>{formatStatus(request.status)}</p>
                  </div>
                  <div>
                    <p style={S.label}>Number:</p>
                    <p style={S.value}>{request.id?.split('-')[0] || 'New'}</p>
                  </div>
                </div>
                <div style={S.grid2}>
                  <div>
                    <p style={S.label}>Profile:</p>
                    <p style={S.value}>{reportedBy?.role ? reportedBy.role.charAt(0).toUpperCase() + reportedBy.role.slice(1) : 'Unknown'}</p>
                  </div>
                  <div>
                    <p style={S.label}>Date Created:</p>
                    <p style={S.value}>{request.scheduled_date ? new Date(request.scheduled_date).toLocaleString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', hour: 'numeric', minute: '2-digit', hour12: true }).replace(',', '') : 'Unknown'}</p>
                  </div>
                </div>
                <div style={{ marginTop: '8px' }}>
                  <p style={S.label}>Created by:</p>
                  <p style={S.value}>{reportedBy?.username || '-'}</p>
                </div>
              </div>

              <div style={S.card}>
                <h3 style={S.cardTitle}>Assigned to</h3>
                {assignedUser ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ ...S.avatar, background: 'rgba(59,130,246,0.2)', color: '#60a5fa' }}>{assigneeInitial}</div>
                    <div>
                      <p style={{ fontSize: '14px', fontWeight: 600, color: '#f8fafc', margin: 0 }}>{assignedUser.username}</p>
                      <p style={{ fontSize: '12px', color: '#94a3b8', margin: 0 }}>{assignedUser.role?.charAt(0).toUpperCase() + assignedUser.role?.slice(1)} • {assignedUser.id?.split('-')[0]}</p>
                    </div>
                  </div>
                ) : (
                  <p style={{ color: '#64748b', fontSize: '14px', margin: 0 }}>Unassigned</p>
                )}
              </div>
            </div>

            {/* CENTER COLUMN: Issue Info & Photos */}
            <div style={{ ...S.card, background: 'transparent', padding: '0 16px', border: '1px solid #1d2540', overflowY: 'auto' }}>
              <div style={{ padding: '24px 0', borderBottom: '1px solid #1d2540' }}>
                <h2 style={{ fontSize: '24px', fontWeight: 600, color: '#f8fafc', margin: '0 0 16px 0', lineHeight: 1.3 }}>{request.equipment ? `Issue with ${request.equipment.split('-')[0]}` : 'Maintenance Issue'}</h2>
                <p style={{ fontSize: '14px', color: '#cbd5e1', lineHeight: 1.6, margin: 0 }}>
                  {request.issue || "No description provided."}
                </p>
              </div>

              <div style={{ padding: '24px 0', borderBottom: '1px solid #1d2540' }}>
                <div style={S.iconRow}>
                  <span style={S.icon}>🖥</span>
                  <p style={{ margin: 0, fontSize: '14px' }}><strong style={{ color: '#f8fafc' }}>Device:</strong> <span style={{ color: '#94a3b8' }}>{request.equipment?.split('-')[0] || 'Unknown'}</span></p>
                </div>
                {/* Omitted location per implementation plan */}
                <div style={{ ...S.iconRow, marginBottom: 0 }}>
                  <span style={S.icon}>🕐</span>
                  <p style={{ margin: 0, fontSize: '14px' }}><strong style={{ color: '#f8fafc' }}>Date and Time:</strong> <span style={{ color: '#94a3b8' }}>{request.scheduled_date ? new Date(request.scheduled_date).toLocaleString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', hour: 'numeric', minute: '2-digit', hour12: true }).replace(',', '') : '-'}</span></p>
                </div>
              </div>

              {attachments.length > 0 && (
                <div style={{ padding: '24px 0', borderBottom: '1px solid #1d2540' }}>
                  <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                    {attachments.map(att => isImage(att.file_type) && (
                      <div key={att.id} onClick={() => setPreviewAttachment(att)} style={{ width: '80px', height: '80px', borderRadius: '8px', overflow: 'hidden', cursor: 'pointer', border: '1px solid #1d2540' }}>
                        <img src={getFileSrc(att.file)} alt={att.file_name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      </div>
                    ))}
                    {attachments.filter(a => !isImage(a.file_type)).map(att => (
                      <a key={att.id} href={getFileSrc(att.file)} target="_blank" rel="noopener noreferrer" style={{ width: '80px', height: '80px', borderRadius: '8px', background: '#0d1022', border: '1px solid #1d2540', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textDecoration: 'none', color: '#94a3b8', fontSize: '11px', padding: '8px', textAlign: 'center', boxSizing: 'border-box' }}>
                        <span style={{ fontSize: '24px', marginBottom: '4px' }}>📄</span>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', width: '100%' }}>{att.file_name}</span>
                      </a>
                    ))}
                  </div>
                </div>
              )}

              <div style={{ padding: '24px 0', display: 'flex', gap: '12px' }}>
                <label style={{ ...S.btnCancel, width: 'fit-content', cursor: uploading ? 'not-allowed' : 'pointer', opacity: uploading ? 0.5 : 1 }}>
                  {uploading ? 'Uploading...' : 'Upload New Image'}
                  <input type="file" style={{ display: 'none' }} onChange={handleUpload} disabled={uploading} />
                </label>
              </div>
            </div>

            {/* RIGHT COLUMN: Updates Chat */}
            <div style={{ ...S.card, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
              <div style={{ padding: '20px 20px 12px', borderBottom: '1px solid #1d2540' }}>
                <h3 style={{ ...S.cardTitle, margin: 0 }}>Updates</h3>
              </div>

              {/* Chat Feed (Scrollable) */}
              <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column' }}>
                {parsedComments.length === 0 ? (
                  <p style={{ color: '#64748b', fontSize: '13px', textAlign: 'center', marginTop: '40px' }}>No updates yet.</p>
                ) : (
                  parsedComments.map((comment, i) => (
                    <div key={i} style={{ display: 'flex', gap: '12px', marginBottom: '20px' }}>
                      <div style={{ ...S.avatar, background: 'rgba(16,185,129,0.2)', color: '#34d399', width: '28px', height: '28px', fontSize: '12px' }}>
                        {comment.user.charAt(0).toUpperCase()}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', alignItems: 'baseline', gap: '8px', marginBottom: '4px' }}>
                          <span style={{ fontSize: '13px', fontWeight: 600, color: '#f8fafc' }}>{comment.user}</span>
                          <span style={{ fontSize: '11px', color: '#64748b' }}>{comment.timestamp.replace(',', '')}</span>
                        </div>
                        <p style={{ fontSize: '13px', color: '#cbd5e1', lineHeight: 1.5, margin: 0 }}>{comment.message}</p>
                      </div>
                    </div>
                  ))
                )}
                <div ref={commentsEndRef} />
              </div>

              {/* Static Input Area */}
              <div style={{ padding: '16px 20px', borderTop: '1px solid #1d2540', background: '#1e253c', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                
                <div style={{ position: 'relative' }}>
                  <select 
                    style={S.select} 
                    value={selectedAssignee}
                    onChange={(e) => setSelectedAssignee(e.target.value)}
                  >
                    <option value="" disabled>Assign To...</option>
                    {users.map((user) => (
                      <option key={user.id} value={user.id}>
                        {user.username} ({user.role})
                        {user.id === request.assigned_to ? ' (Current)' : ''}
                      </option>
                    ))}
                  </select>
                  {/* Select arrow indicator */}
                  <div style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', color: '#94a3b8', fontSize: '10px' }}>▼</div>
                </div>

                <textarea
                  style={S.textarea}
                  rows={2}
                  placeholder="Type a message..."
                  value={newResponse}
                  onChange={e => setNewResponse(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleRespond(); }
                  }}
                />
                <button style={S.btnPrimary} onClick={handleRespond} disabled={!newResponse.trim() || sending}>
                  {sending ? "Sending..." : "Send"}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Image Preview Overlay */}
      {previewAttachment && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '32px' }} onClick={() => setPreviewAttachment(null)}>
          <div style={{ position: 'relative', maxWidth: '90vw', maxHeight: '85vh' }} onClick={e => e.stopPropagation()}>
            {isImage(previewAttachment.file_type) ? (
              <img src={getFileSrc(previewAttachment.file)} alt={previewAttachment.file_name} style={{ maxWidth: '100%', maxHeight: '85vh', borderRadius: '12px', boxShadow: '0 24px 64px rgba(0,0,0,0.6)' }} />
            ) : null}
            <button style={{ position: 'absolute', top: '-16px', right: '-16px', width: '32px', height: '32px', borderRadius: '50%', background: '#1e293b', border: '1px solid #334155', color: '#e2e8f0', fontSize: '18px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }} onClick={() => setPreviewAttachment(null)}>×</button>
          </div>
        </div>
      )}
    </>
  );
};

export default MaintenanceViewModal;