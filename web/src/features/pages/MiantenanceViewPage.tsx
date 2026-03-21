import React, { useState, useEffect, useRef, useCallback } from 'react';
import PageLayout from "../pages/PageLayout";
import { useNavigate, useParams } from 'react-router-dom';
import type { MaintenanceRequest, User, Attachment } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
import { userService } from "../services/userService";
import { equipmentService } from "../services/equipmentService";
import { parseComments } from "../utils/comments";

const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.85)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '32px'
  },
  pageContainer: {
    padding: '32px',
    height: 'calc(100vh - 80px)', // assuming topbar is 80px
    overflow: 'hidden',
    boxSizing: 'border-box' as const,
  },
  headerRow: {
    display: 'flex',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: '24px',
  },
  backButton: {
    background: 'transparent', border: 'none', color: '#94a3b8',
    cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px',
    fontSize: '14px', fontWeight: 500, padding: 0,
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'minmax(280px, 1fr) 2fr minmax(320px, 1.2fr)',
    gap: '24px',
    height: 'calc(100% - 50px)', // minus header
  },
  card: {
    background: '#1e253c', borderRadius: '12px', padding: '24px',
    display: 'flex', flexDirection: 'column' as const,
    border: '1px solid #1d2540'
  },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#f8fafc', margin: '0 0 16px 0' },
  label: { fontSize: '13px', color: '#94a3b8', margin: '0 0 4px 0', fontWeight: 500 },
  value: { fontSize: '14px', color: '#f8fafc', margin: 0 },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' },
  avatar: { width: '32px', height: '32px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600, fontSize: '14px', flexShrink: 0 },
  iconRow: { display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' },
  icon: { fontSize: '18px', color: '#94a3b8', width: '20px', textAlign: 'center' as const },
  btnPrimary: { padding: '10px 16px', borderRadius: '8px', border: 'none', background: '#5b81fb', color: '#fff', fontSize: '13px', fontWeight: 600, cursor: 'pointer', transition: 'background 0.2s', width: '100%', display: 'flex', justifyContent: 'center', alignItems: 'center' },
  btnCancel: { padding: '10px 16px', borderRadius: '8px', border: '1px solid #334155', background: '#0d1022', color: '#e2e8f0', fontSize: '13px', fontWeight: 600, cursor: 'pointer', transition: 'background 0.2s', textAlign: 'center' as const, display: 'inline-block' },
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

const MaintenanceViewPage: React.FC = () => {
  const navigate = useNavigate();
  const { id: requestId } = useParams<{ id: string }>();

  // Core Request State
  const [request, setRequest] = useState<MaintenanceRequest | null>(null);
  const [equipmentName, setEquipmentName] = useState<string>("");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Users State
  const [users, setUsers] = useState<User[]>([]);
  const [currentUser, setCurrentUser] = useState<Partial<User> | null>(null);
  const [reportedBy, setReportedBy] = useState<User | null>(null);
  const [assignedUser, setAssignedUser] = useState<User | null>(null);

  // Attachments State
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const [previewAttachment, setPreviewAttachment] = useState<Attachment | null>(null);
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  // Chat/Update State
  const [tempComments, setTempComments] = useState("");
  const [newResponse, setNewResponse] = useState("");
  const [selectedAssignee, setSelectedAssignee] = useState<string>("");
  const [sending, setSending] = useState(false);
  const commentsEndRef = useRef<HTMLDivElement>(null);

  const getFileSrc = useCallback((src: string): string => {
    if (!src) return "";
    if (src.startsWith("blob:") || /^https?:\/\//.test(src)) return src;
    return `${window.location.origin}${src.startsWith('/') ? '' : '/'}${src}`;
  }, []);

  const isImage = useCallback((type: string) => type.startsWith('image/'), []);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const allUsers = await userService.getAll();
        setUsers(allUsers);
        // Fallback user placeholder
        setCurrentUser({ id: 'current', username: 'Current User', role: 'admin' });
      } catch (err) {
        console.error("Failed to fetch users");
      }
    };
    fetchUsers();
  }, []);

  useEffect(() => {
    const fetchRequest = async () => {
      if (!requestId) return;
      try {
        setIsLoading(true);
        const fetched = await maintenanceService.getById(requestId);
        setRequest(fetched);
        setAttachments(fetched.attachments ?? []);
        setTempComments(fetched.comments || "");
        setSelectedAssignee(fetched.assigned_to || "");

        if (fetched.equipment) {
          try {
            const eq = await equipmentService.getById(fetched.equipment);
            setEquipmentName(eq.name || fetched.equipment);
          } catch {
            setEquipmentName(fetched.equipment);
          }
        }
      } catch (err) {
        setError("Failed to load request.");
      } finally {
        setIsLoading(false);
      }
    };
    fetchRequest();
  }, [requestId]);

  useEffect(() => {
    if (request && users.length > 0) {
      if (request.user) {
        const rep = users.find(u => u.id === request.user) || (currentUser?.id === request.user ? currentUser as User : null);
        setReportedBy(rep);
      }
      if (request.assigned_to) {
        const ass = users.find(u => u.id === request.assigned_to) || (currentUser?.id === request.assigned_to ? currentUser as User : null);
        setAssignedUser(ass);
      }
    }
  }, [request, users, currentUser]);

  useEffect(() => {
    commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [tempComments]);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPreviewAttachment(null);
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, []);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !request?.id || uploading) return;
    setUploading(true);
    
    const tempAtt: Attachment = { id: `temp-${Date.now()}`, file: URL.createObjectURL(file), file_name: file.name, maintenance_request: request.id, file_type: file.type, uploaded_at: new Date().toISOString() };
    setAttachments(p => [...p, tempAtt]);
    
    try {
      const realAtt = await maintenanceService.uploadAttachment(request.id, file, file.name);
      setAttachments(p => p.map(a => a.id === tempAtt.id ? realAtt : a));
    } catch (err) {
      setAttachments(p => p.filter(a => a.id !== tempAtt.id));
      console.error("Upload failed", err);
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const handleDeleteAttachment = async (attachmentId: string) => {
    if (deletingId || !request?.id) return;
    setDeletingId(attachmentId);
    try {
      await maintenanceService.deleteAttachment(attachmentId);
      setAttachments(prev => prev.filter(a => a.id !== attachmentId));
    } catch (err) {
      console.error("Failed to delete", err);
    } finally {
      setDeletingId(null);
    }
  };

  const handleAssignSubmit = async () => {
    if (!request?.id || !selectedAssignee) return;

    try {
      const userObj = users.find(u => u.id === selectedAssignee);
      if (userObj) setAssignedUser(userObj);

      const updated = await maintenanceService.respond(request.id, {
        response: `Reassigned ticket to ${userObj?.username || 'Unassigned'}`,
        assigned_to: selectedAssignee
      });
      setTempComments(updated.comments || "");
      setRequest(updated);
    } catch (err) {
      console.error("Failed to reassign", err);
    }
  };

  const handleRespond = async () => {
    if (!newResponse.trim() || !request?.id || sending) return;
    setSending(true);
    const text = newResponse;
    const now = new Date().toLocaleString();
    const roleLabel = currentUser?.role ? currentUser.role.charAt(0).toUpperCase() + currentUser.role.slice(1) : 'Admin';
    const appendEntry = `\n[${now}] ${currentUser?.username || 'Unknown'} (${roleLabel}): ${text}`;
    
    const optimistic = tempComments + appendEntry;
    setTempComments(optimistic);
    setNewResponse("");

    const payload: { response: string } = { response: text };

    try {
      const updated = await maintenanceService.respond(request.id, payload);
      setTempComments(updated.comments || "");
      setRequest(updated);
    } catch (e) {
      setTempComments(request.comments || "");
      setNewResponse(text); // restore
      console.error("Failed response", e);
    } finally {
      setSending(false);
    }
  };

  if (isLoading) {
    return (
      <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
        <div style={{...S.pageContainer, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
          <p style={{ color: '#94a3b8' }}>Loading request...</p>
        </div>
      </PageLayout>
    );
  }

  if (!request || error) {
    return (
      <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
        <div style={{...S.pageContainer, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center'}}>
          <p style={{ color: '#ef4444', marginBottom: '16px' }}>{error || "Request not found"}</p>
          <button style={{...S.btnPrimary, width: 'auto'}} onClick={() => navigate('/dashboard/maintenance')}>Return to Dashboard</button>
        </div>
      </PageLayout>
    );
  }

  const parsedComments = parseComments(tempComments);
  const assigneeInitial = (assignedUser?.username || '?').charAt(0).toUpperCase();

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
      <div style={S.pageContainer}>
        
        <div style={S.headerRow}>
          <div style={{ flex: 1, paddingRight: '24px' }}>
            <h2 style={{ fontSize: '24px', fontWeight: 600, color: '#f8fafc', margin: '0 0 8px 0', lineHeight: 1.3 }}>
              {equipmentName ? `Issue with ${equipmentName}` : 'Maintenance Issue'}
            </h2>
            <p style={{ fontSize: '14px', color: '#cbd5e1', lineHeight: 1.6, margin: 0 }}>
              {request.issue || "No description provided."}
            </p>
          </div>
          <button style={S.backButton} onClick={() => navigate('/dashboard/maintenance')}>
            <span>←</span> Back to Maintenance
          </button>
        </div>

        <div style={S.grid}>
          
          {/* LEFT COLUMN: Details & Assigned */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

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
              {assignedUser && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
                  <div style={{ ...S.avatar, background: 'rgba(59,130,246,0.2)', color: '#60a5fa' }}>{assigneeInitial}</div>
                  <div>
                    <p style={{ fontSize: '14px', fontWeight: 600, color: '#f8fafc', margin: 0 }}>{assignedUser.username}</p>
                    <p style={{ fontSize: '12px', color: '#94a3b8', margin: 0 }}>{assignedUser.role?.charAt(0).toUpperCase() + assignedUser.role?.slice(1)} • {assignedUser.id?.split('-')[0]}</p>
                  </div>
                </div>
              )}
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
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
                  <div style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', color: '#94a3b8', fontSize: '10px' }}>▼</div>
                </div>
                <button 
                  style={{ ...S.btnPrimary, background: '#334155', color: '#f8fafc' }}
                  onClick={handleAssignSubmit}
                  disabled={!selectedAssignee || selectedAssignee === request?.assigned_to}
                >
                  Assign User
                </button>
              </div>
            </div>
          </div>

          {/* CENTER COLUMN: Issue Info & Photos */}
          <div style={{ ...S.card, padding: '0 24px' }}>
            <div style={{ padding: '24px 0', borderBottom: '1px solid #1d2540' }}>
              <div style={S.iconRow}>
                <span style={S.icon}>🖥</span>
                <p style={{ margin: 0, fontSize: '14px' }}><strong style={{ color: '#f8fafc' }}>Device:</strong> <span style={{ color: '#94a3b8' }}>{equipmentName || 'Unknown'}</span></p>
              </div>
              <div style={{ ...S.iconRow, marginBottom: 0 }}>
                <span style={S.icon}>🕐</span>
                <p style={{ margin: 0, fontSize: '14px' }}><strong style={{ color: '#f8fafc' }}>Date and Time:</strong> <span style={{ color: '#94a3b8' }}>{request.scheduled_date ? new Date(request.scheduled_date).toLocaleString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', hour: 'numeric', minute: '2-digit', hour12: true }).replace(',', '') : '-'}</span></p>
              </div>
            </div>

            {attachments.length > 0 && (
              <div style={{ padding: '24px 0', borderBottom: '1px solid #1d2540' }}>
                <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                  {attachments.map(att => isImage(att.file_type) && (
                    <div key={att.id} style={{ position: 'relative', width: '80px', height: '80px', borderRadius: '8px', overflow: 'hidden', border: '1px solid #1d2540' }}>
                      <div onClick={() => setPreviewAttachment(att)} style={{ width: '100%', height: '100%', cursor: 'pointer' }}>
                        <img src={getFileSrc(att.file)} alt={att.file_name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      </div>
                      <button 
                        onClick={(e) => { e.stopPropagation(); setConfirmDeleteId(att.id); }}
                        disabled={deletingId === att.id}
                        style={{ position: 'absolute', top: '4px', right: '4px', width: '20px', height: '20px', borderRadius: '50%', background: 'rgba(15,23,42,0.8)', color: '#ef4444', border: '1px solid #ef4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', padding: 0 }}
                      >
                        {deletingId === att.id ? '...' : '×'}
                      </button>
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
              <label style={{ ...S.btnCancel, cursor: uploading ? 'not-allowed' : 'pointer', opacity: uploading ? 0.5 : 1 }}>
                {uploading ? 'Uploading...' : 'Upload New Image'}
                <input type="file" style={{ display: 'none' }} onChange={handleUpload} disabled={uploading} />
              </label>
            </div>
          </div>

          {/* RIGHT COLUMN: Updates Chat */}
          <div style={{ ...S.card, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid #1d2540' }}>
              <h3 style={{ ...S.cardTitle, margin: 0 }}>Updates</h3>
            </div>

            {/* Chat Feed */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px', display: 'flex', flexDirection: 'column' }}>
              {parsedComments.length === 0 ? (
                <p style={{ color: '#64748b', fontSize: '13px', textAlign: 'center', marginTop: '40px' }}>No updates yet.</p>
              ) : (
                parsedComments.map((comment, i) => (
                  <div key={i} style={{ display: 'flex', gap: '12px', marginBottom: '20px' }}>
                    <div style={{ ...S.avatar, background: 'rgba(16,185,129,0.2)', color: '#34d399', width: '32px', height: '32px', fontSize: '13px' }}>
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

            {/* Input Area */}
            <div style={{ padding: '20px', borderTop: '1px solid #1d2540', background: '#191f33', display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <textarea
                style={S.textarea}
                rows={3}
                placeholder="Type your update here..."
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

      {confirmDeleteId && (
        <div style={S.backdrop} onClick={() => setConfirmDeleteId(null)}>
          <div style={{ ...S.card, maxWidth: '400px', width: '100%', position: 'relative', textAlign: 'center' }} onClick={e => e.stopPropagation()}>
            <h3 style={{ ...S.cardTitle, margin: '0 0 16px 0', fontSize: '20px' }}>Confirm Deletion</h3>
            <p style={{ color: '#cbd5e1', fontSize: '14px', marginBottom: '24px' }}>Are you sure you want to delete this attachment? This action cannot be undone.</p>
            <div style={{ display: 'flex', gap: '12px' }}>
              <button 
                style={{ ...S.btnCancel, flex: 1 }} 
                onClick={() => setConfirmDeleteId(null)}
              >
                Cancel
              </button>
              <button 
                style={{ ...S.btnPrimary, background: '#ef4444', flex: 1 }} 
                onClick={() => { handleDeleteAttachment(confirmDeleteId); setConfirmDeleteId(null); }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {previewAttachment && (
        <div style={S.backdrop} onClick={() => setPreviewAttachment(null)}>
          <div style={{ position: 'relative', maxWidth: '90vw', maxHeight: '85vh' }} onClick={e => e.stopPropagation()}>
            {isImage(previewAttachment.file_type) ? (
              <img src={getFileSrc(previewAttachment.file)} alt={previewAttachment.file_name} style={{ maxWidth: '100%', maxHeight: '85vh', borderRadius: '12px', boxShadow: '0 24px 64px rgba(0,0,0,0.6)' }} />
            ) : null}
            <button style={{ position: 'absolute', top: '-16px', right: '-16px', width: '32px', height: '32px', borderRadius: '50%', background: '#1e293b', border: '1px solid #334155', color: '#e2e8f0', fontSize: '18px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }} onClick={() => setPreviewAttachment(null)}>×</button>
          </div>
        </div>
      )}
    </PageLayout>
  );
};

export default MaintenanceViewPage;