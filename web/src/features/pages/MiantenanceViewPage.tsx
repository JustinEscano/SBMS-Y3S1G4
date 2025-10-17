// src/features/pages/MaintenanceViewPage.tsx
import React, { useState, useEffect, useRef, useCallback } from 'react';
import './MaintenanceViewPage.css';
import PageLayout from "../pages/PageLayout";
import '../pages/PageStyle.css';
import { useNavigate, useParams } from 'react-router-dom';
import type { MaintenanceRequest, User, Attachment } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
import { userService } from "../services/userService";
import { equipmentService } from "../services/equipmentService"; // Assume this service exists for fetching equipment details
import { parseComments } from "../utils/comments";

const MaintenanceViewPage: React.FC = () => {
  const navigate = useNavigate();
  const { id: requestId } = useParams<{ id: string }>();
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // States
  const [request, setRequest] = useState<MaintenanceRequest | null>(null);
  const [equipmentName, setEquipmentName] = useState<string>(""); // New state for equipment name
  const [users, setUsers] = useState<User[]>([]); // Assume fetched or from context; fetch if empty
  const [currentUser, setCurrentUser] = useState<Partial<User> | null>(null); // From auth context
  const [reportedBy, setReportedBy] = useState<User | null>(null);
  const [reportedByLoading, setReportedByLoading] = useState(true);
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const [newFile, setNewFile] = useState<File | null>(null);
  const [previewAttachment, setPreviewAttachment] = useState<Attachment | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [newResponse, setNewResponse] = useState("");
  const [assignedTo, setAssignedTo] = useState<string | null>(null);
  const [tempComments, setTempComments] = useState("");
  const [status, setStatus] = useState("pending");
  const [scheduledDate, setScheduledDate] = useState<string | null>(null);
  const [resolvedDate, setResolvedDate] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  // New states for delete modal
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [pendingDeleteId, setPendingDeleteId] = useState<string | null>(null);
  // New: For temp upload discard modal text
  const [isTempDelete, setIsTempDelete] = useState(false);

  // Helper to format ISO string for datetime-local input
  const formatForInput = useCallback((isoString: string | null): string => {
    if (!isoString) return '';
    return new Date(isoString).toISOString().slice(0, 16);
  }, []);

  // Fetch request on mount
  useEffect(() => {
    const fetchRequest = async () => {
      if (!requestId) return;
      try {
        setIsLoading(true);
        const fetchedRequest = await maintenanceService.getById(requestId);
        setRequest(fetchedRequest);
        setAttachments(fetchedRequest.attachments ?? []);
        setTempComments(fetchedRequest.comments || "");
        setStatus(fetchedRequest.status || "pending");
        setAssignedTo(fetchedRequest.assigned_to ?? null);
        setScheduledDate(fetchedRequest.scheduled_date ?? null);
        setResolvedDate(fetchedRequest.resolved_at ?? null);
        // Fetch equipment name if equipment is an ID
        if (fetchedRequest.equipment) {
          try {
            const equipmentDetails = await equipmentService.getById(fetchedRequest.equipment);
            setEquipmentName(equipmentDetails.name || fetchedRequest.equipment);
          } catch (err) {
            console.error("Failed to fetch equipment name:", err);
            setEquipmentName(fetchedRequest.equipment); // Fallback to ID
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

  // Fetch users and currentUser (simplified; integrate with auth/context as needed)
  useEffect(() => {
    const initUsers = async () => {
      try {
        const allUsers = await userService.getAll(); // Assume service method
        setUsers(allUsers);
        // Set currentUser from auth or localStorage
        const user = { id: 'current', username: 'Current User', role: 'Admin' } as User; // Placeholder
        setCurrentUser(user);
      } catch (err) {
        console.error("Failed to load users.");
      }
    };
    if (users.length === 0) initUsers();
  }, []);

  // Fetch reportedBy
  useEffect(() => {
    const fetchReporter = async () => {
      if (!request?.user || !currentUser) {
        setReportedByLoading(false);
        return;
      }
      setReportedByLoading(true);

      if ((currentUser as User).id === request.user) {
        setReportedBy(currentUser as User);
        setReportedByLoading(false);
        return;
      }

      let user = users.find(u => u.id === request.user);
      if (!user) {
        try {
          user = await userService.getById(request.user);
        } catch (err: any) {
          user = { id: request.user, username: 'Unknown User', email: '', role: 'Client' } as User;
        }
      }
      setReportedBy(user);
      setReportedByLoading(false);
    };
    fetchReporter();
  }, [request?.user, users, currentUser]);

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = Math.min(textareaRef.current.scrollHeight, 200) + 'px';
    }
  }, [newResponse]);

  // Cleanup blob URLs
  useEffect(() => {
    return () => {
      attachments.forEach(att => {
        if (att.file && typeof att.file === 'string' && att.file.startsWith('blob:')) {
          URL.revokeObjectURL(att.file);
        }
      });
    };
  }, [attachments]);

  // Escape for preview
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPreviewAttachment(null);
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, []);

  const getFileSrc = useCallback((src: string): string => {
    if (!src) return "";
    if (src.startsWith("blob:")) return src;
    if (/^https?:\/\//.test(src)) return src;
    return `${window.location.origin}${src.startsWith('/') ? '' : '/'}${src}`;
  }, []);

  const isImage = useCallback((type: string) => type.startsWith('image/'), []);

  const handleDeleteAttachment = useCallback(async (attachmentId: string): Promise<void> => {
    if (deletingId || !requestId) return;
    setDeletingId(attachmentId);
    setError(null);

    const prevAttachments = attachments;
    setAttachments(prev => prev.filter(a => a.id !== attachmentId));

    try {
      await maintenanceService.deleteAttachment(attachmentId);
      // Refresh
      const refreshed = await maintenanceService.getById(requestId);
      setRequest(refreshed);
      setAttachments(refreshed.attachments ?? []);
    } catch (err) {
      console.error("Failed to delete:", err);
      setAttachments(prevAttachments);
      setError(`Failed to delete attachment.`);
    } finally {
      setDeletingId(null);
    }
  }, [deletingId, attachments, requestId]);

  // New: Open delete modal
  const openDeleteModal = useCallback((id: string, isTemp = false) => {
    setPendingDeleteId(id);
    setIsTempDelete(isTemp);
    setShowDeleteModal(true);
  }, []);

  // New: Confirm delete from modal
  const confirmDelete = useCallback(() => {
    if (pendingDeleteId && isTempDelete) {
      setNewFile(null);
    } else if (pendingDeleteId) {
      handleDeleteAttachment(pendingDeleteId);
    }
    setShowDeleteModal(false);
    setPendingDeleteId(null);
    setIsTempDelete(false);
  }, [pendingDeleteId, isTempDelete, handleDeleteAttachment]);

  const handleUpload = useCallback(async (e: React.MouseEvent): Promise<void> => {
    e.stopPropagation();
    if (!newFile || !requestId) return;
    setError(null);

    const tempAttachment: Attachment = {
      id: `temp-${Date.now()}`,
      file: URL.createObjectURL(newFile),
      file_name: newFile.name,
      maintenance_request: requestId,
      file_type: newFile.type,
      uploaded_at: new Date().toISOString(),
    };
    const prevAttachments = attachments;
    setAttachments(prev => [...prev, tempAttachment]);

    try {
      const realAttachment = await maintenanceService.uploadAttachment(requestId, newFile, newFile.name);
      setAttachments(prev => prev.map(a => a.id === tempAttachment.id ? realAttachment : a));
      // Refresh
      const refreshed = await maintenanceService.getById(requestId);
      setRequest(refreshed);
      setAttachments(refreshed.attachments ?? []);
    } catch (err) {
      console.error("Failed to upload:", err);
      setAttachments(prevAttachments);
      setError(`Failed to upload "${newFile.name}".`);
    } finally {
      setNewFile(null);
    }
  }, [newFile, attachments, requestId]);

  const handleRespond = useCallback(async (e: React.MouseEvent): Promise<void> => {
    e.stopPropagation();
    if (!newResponse.trim() || !requestId) return;
    const now = new Date().toLocaleString();
    const appendEntry = `\n[${now}] ${currentUser?.username || 'Unknown'} (${(currentUser as User)?.role || 'Admin'}): ${newResponse}`;
    const optimisticComments = tempComments + appendEntry;
    setTempComments(optimisticComments);

    // Omit or convert null assigned_to to undefined to match service typing (assigned_to?: string)
    const payload = {
      response: newResponse,
      assigned_to: assignedTo ?? undefined
    };
    setNewResponse("");

    try {
      const updated = await maintenanceService.respond(requestId, payload);
      setTempComments(updated.comments || "");
      setRequest(updated);
      // Refresh full
      const refreshed = await maintenanceService.getById(requestId);
      setRequest(refreshed);
      setTempComments(refreshed.comments || "");
      setAssignedTo(refreshed.assigned_to ?? null);
      setScheduledDate(refreshed.scheduled_date ?? null);
      setResolvedDate(refreshed.resolved_at ?? null);
    } catch (err) {
      console.error("Failed to respond:", err);
      // Rollback via refresh
      const refreshed = await maintenanceService.getById(requestId);
      setRequest(refreshed);
      setTempComments(refreshed.comments || "");
      setAssignedTo(refreshed.assigned_to ?? null);
      setScheduledDate(refreshed.scheduled_date ?? null);
      setResolvedDate(refreshed.resolved_at ?? null);
    }
  }, [newResponse, tempComments, currentUser, assignedTo, requestId]);

  const handleStatusChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    e.stopPropagation();
    const newStatus = e.target.value;
    setStatus(newStatus);
    // Auto-set dates if not already set
    if (newStatus === 'resolved' && !resolvedDate) {
      setResolvedDate(new Date().toISOString());
    }
    if ((newStatus === 'in_progress' || newStatus === 'pending') && !scheduledDate) {
      setScheduledDate(new Date().toISOString());
    }
  }, [scheduledDate, resolvedDate]);

  const handleAssignChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    e.stopPropagation();
    setAssignedTo(e.target.value === "" ? null : e.target.value);
  }, []);

  const handleScheduledDateChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setScheduledDate(e.target.value ? new Date(e.target.value).toISOString() : null);
  }, []);

  const handleResolvedDateChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setResolvedDate(e.target.value ? new Date(e.target.value).toISOString() : null);
  }, []);

  // New: Save status changes only
  const handleSaveChanges = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!requestId || !request) return;
    try {
      // Prepare full payload with required fields and overrides, excluding id
      const { id, ...basePayload } = request;
      const updatePayload: Partial<MaintenanceRequest> = {
        ...basePayload,
        status: status as MaintenanceRequest['status'],
        scheduled_date: scheduledDate ?? undefined,
        resolved_at: resolvedDate ?? undefined,
      };

      await maintenanceService.update(requestId, updatePayload);
      // Refresh to confirm
      const refreshed = await maintenanceService.getById(requestId);
      setRequest(refreshed);
      setStatus(refreshed.status || "pending");
      setScheduledDate(refreshed.scheduled_date ?? null);
      setResolvedDate(refreshed.resolved_at ?? null);
    } catch (err) {
      console.error("Failed to save changes:", err);
      setError("Failed to save changes.");
    }
  }, [requestId, request, status, scheduledDate, resolvedDate]);

  const parsedComments = parseComments(tempComments);

  // Get current assigned user name
  const currentAssignedUser = request?.assigned_to ? users.find(u => u.id === request.assigned_to)?.username || "Unknown" : "Unassigned";

  if (isLoading) {
    return (
      <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
        <main className="main-content">
          <div className="loading-placeholder">Loading...</div>
        </main>
      </PageLayout>
    );
  }

  if (!request) {
    return (
      <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
        <main className="main-content">
          <div className="error-placeholder">Request not found.</div>
        </main>
      </PageLayout>
    );
  }

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance View" }}>
      {error && <div className="error-message">{error}</div>}
      {/* Main Content */}
      <main className="main-content">
        {/* Left Panel */}
        <section className="left-panel">
          <div className="status-card">
            <div className="status-header">
              <span className="status-icon">⭕</span>
              <div>
                <h3>STATUS: {status.toUpperCase()}</h3>
                <p>Assigned to: {currentAssignedUser}</p>
              </div>
            </div>
            <div className="client-info">
              <h3>Client</h3>
              <p>{reportedByLoading ? "Loading..." : (reportedBy?.username || "Unknown")}</p>
              <p>{new Date(request.created_at || Date.now()).toLocaleString()}</p>
            </div>
            <div className="action-buttons">
              <div className="dropdown-wrapper">
                <label className="dropdown-label">Status:</label>
                <select
                  value={status}
                  onChange={handleStatusChange}
                  className="full-select"
                >
                  <option value="pending">Pending</option>
                  <option value="in_progress">In Progress</option>
                  <option value="resolved">Resolved</option>
                </select>
              </div>
              {(status === 'pending' || status === 'in_progress') && (
                <div className="dropdown-wrapper">
                  <label className="dropdown-label">Scheduled Date:</label>
                  <input
                    type="datetime-local"
                    value={formatForInput(scheduledDate)}
                    onChange={handleScheduledDateChange}
                    className="date-input"
                  />
                </div>
              )}
              {status === 'resolved' && (
                <div className="dropdown-wrapper">
                  <label className="dropdown-label">Resolved Date:</label>
                  <input
                    type="datetime-local"
                    value={formatForInput(resolvedDate)}
                    onChange={handleResolvedDateChange}
                    className="date-input"
                  />
                </div>
              )}
              {/* New: Save button for status only */}
              <button
                onClick={handleSaveChanges}
                className="save-changes-btn"
                disabled={status === request.status}
              >
                Save Changes
              </button>
            </div>
          </div>

          <button className="btn-chat" onClick={() => navigate(`/dashboard/maintenance`)}>Back to Maintenance</button>
        </section>

        {/* Right Panels */}
        <section className="right-panels">
          {/* Details Panel */}
          <article className="details-panel">
            <h2>{equipmentName}</h2> {/* Updated to use equipment name */}
            <p>{request.issue}</p>
            <div className="detail-item">
              <span className="detail-label">Date and Time:</span>
              <span>{new Date(request.created_at || Date.now()).toLocaleString()}</span>
            </div>
            {/* Attachments Grid */}
            <div className="attachments-section">
              <h3 className="attachments-h3">Attachments</h3>
              {attachments.length > 0 ? (
                <div className="attachments-grid">
                  {attachments.map((att) => (
                    <div key={att.id} className="attachment-item">
                      {isImage(att.file_type) ? (
                        <button
                          onClick={(e) => { e.stopPropagation(); setPreviewAttachment(att); }}
                          className="thumb-button"
                          aria-label={`Preview ${att.file_name}`}
                        >
                          <img
                            src={getFileSrc(att.file)}
                            alt={att.file_name}
                            className="thumb-image"
                          />
                        </button>
                      ) : (
                        <div className="file-link-wrapper">
                          <a href={getFileSrc(att.file)} target="_blank" rel="noopener noreferrer" className="file-link">
                            📎 {att.file_name.substring(0, 10)}...
                          </a>
                        </div>
                      )}
                      <button
                        onClick={(e) => { e.stopPropagation(); openDeleteModal(att.id); }}
                        disabled={deletingId === att.id}
                        className={`grid-delete-btn ${deletingId === att.id ? 'loading' : ''}`}
                      >
                        {deletingId === att.id ? '...' : '×'}
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="no-attachments">No attachments</p>
              )}
              {error && <div className="attachment-error">{error}</div>}
            </div>
            <hr className="section-divider" />
            {/* Upload New */}
            <div className="upload-section">
              <h4 className="upload-h4">Add New Attachment</h4>
              <input
                type="file"
                onChange={(e) => { e.stopPropagation(); setNewFile(e.target.files?.[0] ?? null); }}
                className="file-input"
              />
              {newFile && isImage(newFile.type) && (
                <div className="preview-grid">
                  <img
                    src={URL.createObjectURL(newFile)}
                    alt="Preview"
                    className="thumb-image"
                  />
                  <button
                    onClick={(e) => { e.stopPropagation(); openDeleteModal('temp-upload', true); }}
                    className="upload-delete-btn"
                  >
                    ×
                  </button>
                </div>
              )}
              <button
                onClick={handleUpload}
                disabled={!newFile}
                className={`upload-btn ${!newFile ? 'disabled' : 'active'}`}
              >
                Upload New
              </button>
            </div>
          </article>

          {/* Updates Panel */}
          <article className="updates-panel">
            <h2>Updates</h2>
            {parsedComments.length > 0 ? (
              parsedComments.map((entry, index) => (
                <div key={index} className="update-item">
                  <div className="update-content">
                    <p className="update-author">{entry.user} ({entry.role})</p>
                    <p className="update-time">[{entry.timestamp}]</p>
                    <p>{entry.message}</p>
                  </div>
                </div>
              ))
            ) : (
              <p className="no-updates">No updates yet.</p>
            )}
            {/* New Response */}
            <div className="new-response-section">
              <label className="response-label">
                Add New Response:
                <textarea
                  ref={textareaRef}
                  value={newResponse}
                  onChange={(e) => { e.stopPropagation(); setNewResponse(e.target.value); }}
                  placeholder="Enter your update here..."
                  className="response-textarea"
                />
              </label>
              <div className="dropdown-wrapper">
                <label className="dropdown-label">Assign to:</label>
                <select
                  value={assignedTo ?? ""}
                  onChange={handleAssignChange}
                  className="full-select"
                >
                  <option value="">Unassigned</option>
                  {users.map((u) => (
                    <option key={u.id} value={u.id}>{u.username}</option>
                  ))}
                </select>
              </div>
              <button
                onClick={handleRespond}
                disabled={!newResponse.trim()}
                className={`post-btn ${!newResponse.trim() ? 'disabled' : 'active'}`}
              >
                Post Comment
              </button>
            </div>
          </article>
        </section>
      </main>

      {/* New: Delete Confirmation Modal */}
      {showDeleteModal && (
        <div className="delete-modal-backdrop" onClick={(e) => { e.stopPropagation(); setShowDeleteModal(false); }}>
          <div className="delete-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Confirm {isTempDelete ? 'Discard' : 'Delete'}</h3>
            <p>Are you sure you want to {isTempDelete ? 'discard this attachment' : 'delete this attachment'}?</p>
            <div className="modal-buttons">
              <button className="btn-secondary" onClick={(e) => { e.stopPropagation(); setShowDeleteModal(false); }}>
                Cancel
              </button>
              <button className="btn-danger" onClick={(e) => { e.stopPropagation(); confirmDelete(); }}>
                {isTempDelete ? 'Discard' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Image Preview Overlay */}
      {previewAttachment && (
        <div
          className="image-preview-backdrop"
          onClick={(e) => { e.stopPropagation(); setPreviewAttachment(null); }}
        >
          <div
            className="image-preview-modal"
            onClick={(e) => e.stopPropagation()}
          >
            {isImage(previewAttachment.file_type) ? (
              <img
                src={getFileSrc(previewAttachment.file)}
                alt={previewAttachment.file_name}
                className="preview-image"
              />
            ) : (
              <div className="preview-fallback">
                <p>Preview not available for {previewAttachment.file_type}.{' '}
                  <a href={getFileSrc(previewAttachment.file)} target="_blank" rel="noopener noreferrer" className="file-link">
                    Download
                  </a>
                </p>
              </div>
            )}
            {/* New: Separate delete button in preview */}
            <button
              onClick={(e) => { e.stopPropagation(); openDeleteModal(previewAttachment.id); }}
              disabled={deletingId === previewAttachment.id}
              className={`preview-delete-btn ${deletingId === previewAttachment.id ? 'loading' : ''}`}
            >
              {deletingId === previewAttachment.id ? '...' : 'Delete'}
            </button>
            {/* Close button (X) - now close-only */}
            <button
              onClick={(e) => { e.stopPropagation(); setPreviewAttachment(null); }}
              className="preview-close-btn"
            >
              &times;
            </button>
          </div>
        </div>
      )}
    </PageLayout>
  );
};

export default MaintenanceViewPage;