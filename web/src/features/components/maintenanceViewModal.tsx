import React, { useState, useEffect } from "react";
import type { MaintenanceRequest, User, Attachment } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
import { userService } from "../services/userService"; // Adjust path if needed
import { parseComments } from "../utils/comments"; // Add back for response parsing
import "./Modal.css";
import "./maintenanceOnly.css";

interface MaintenanceViewModalProps {
  request: MaintenanceRequest;
  users: User[];
  currentUser?: Partial<User> | null; // Assume from auth context
  onClose: () => void;
  onRefresh: () => void;
  updateRequest?: (id: string, data: Partial<MaintenanceRequest>) => Promise<MaintenanceRequest>;
}

const MaintenanceViewModal: React.FC<MaintenanceViewModalProps> = ({
  request,
  users,
  currentUser,
  onClose,
  onRefresh,
  updateRequest,
}) => {
  if (!request) return null;

  const [reportedBy, setReportedBy] = useState<User | null>(null);
  const [reportedByLoading, setReportedByLoading] = useState(true);
  const [page, setPage] = useState<1 | 2>(1);
  const [attachments, setAttachments] = useState<Attachment[]>(request.attachments ?? []);
  const [newFile, setNewFile] = useState<File | null>(null);
  const [previewAttachment, setPreviewAttachment] = useState<Attachment | null>(null); // For image preview modal
  const [deletingId, setDeletingId] = useState<string | null>(null); // For optimistic delete loading
  const [replacingId, setReplacingId] = useState<string | null>(null); // For replace mode
  const [replaceFile, setReplaceFile] = useState<File | null>(null); // Temp file for replace
  const [error, setError] = useState<string | null>(null); // For delete/upload errors
  const [newResponse, setNewResponse] = useState(""); // For page 2
  const [assignedTo, setAssignedTo] = useState(request.assigned_to ?? ""); // For page 2
  const [tempComments, setTempComments] = useState(request.comments || ""); // For optimistic comments

  // Helper to get correct image/file URL
  const getFileSrc = (src: string): string => {
    if (!src) return "";
    if (src.startsWith("blob:")) return src;
    if (/^https?:\/\//.test(src)) return src;
    // Assume relative path, prepend origin
    return `${window.location.origin}${src.startsWith('/') ? '' : '/'}${src}`;
  };

  // Fetch reportedBy if not in local users list
  // Updated useEffect in MaintenanceViewModal
useEffect(() => {
  const fetchReporter = async () => {
    if (!request.user) {
      setReportedByLoading(false);
      return;
    }

    console.log('Fetching reporter for ID:', request.user); // Debug

    // Priority 1: If it's the current user (self-report), use directly
    if (currentUser?.id === request.user) {
      console.log('Using currentUser for reporter'); // Debug
      setReportedBy(currentUser as User); // Assumes currentUser has username/role
      setReportedByLoading(false);
      return;
    }

    // Priority 2: Check local users list
    let user = users.find(u => u.id === request.user);
    console.log('Found in users prop?', !!user); // Debug

    if (!user) {
      try {
        console.log('Fetching via service...'); // Debug
        user = await userService.getById(request.user);
        console.log('Fetched user:', user); // Debug: Inspect response
      } catch (err: any) {
        console.error("Failed to fetch reporter:", err.response?.status, err.response?.data || err.message);
        // Fallback: Construct minimal user if partial data available
        user = { id: request.user, username: 'Unknown User', email: '', role: 'Client' } as User; // Or pull from request if embedded
      }
    }

    setReportedBy(user);
    setReportedByLoading(false);
  };
  fetchReporter();
}, [request.user, users, currentUser]); // Added currentUser dep

  const handleDeleteAttachment = async (attachmentId: string, isTemp: boolean = false): Promise<void> => {
    if (deletingId) return; // Prevent concurrent deletes
    setDeletingId(attachmentId);
    setError(null); // Clear previous errors

    // Optimistic: Remove from list
    const prevAttachments = attachments;
    setAttachments(prev => prev.filter(a => a.id !== attachmentId));

    try {
      if (!isTemp && request.id) {
        await maintenanceService.deleteAttachment(attachmentId); // Pass only attachmentId
      }
      // If successful, refresh to sync any other changes
      await onRefresh();
    } catch (err) {
      console.error("Failed to delete attachment:", err);
      // Rollback optimistic update
      setAttachments(prevAttachments);
      setError(`Failed to delete "${attachments.find(a => a.id === attachmentId)?.file_name || attachmentId}". Please try again.`);
      // Still refresh to ensure consistency
      await onRefresh();
    } finally {
      setDeletingId(null);
    }
  };

  // --- Handle Replace Attachment (upload new, delete old) ---
  const handleReplaceAttachment = async (oldId: string): Promise<void> => {
    if (!replaceFile || !request.id) return;
    setReplacingId(oldId);
    setError(null);

    const tempAttachment: Attachment = {
      ...attachments.find(a => a.id === oldId)!,
      id: `temp-replace-${Date.now()}`,
      file: URL.createObjectURL(replaceFile),
      file_name: replaceFile.name,
      file_type: replaceFile.type,
      uploaded_at: new Date().toISOString(),
    };
    // Optimistic: Swap in list
    const prevAttachments = attachments;
    setAttachments(prev => prev.map(a => a.id === oldId ? tempAttachment : a));

    try {
      // Upload new (service handles association via requestId)
      const newAttachment = await maintenanceService.uploadAttachment(request.id, replaceFile, replaceFile.name);
      // Delete old
      await maintenanceService.deleteAttachment(oldId);
      // Replace with real new (but since we refresh next, optional)
      setAttachments(prev => prev.map(a => a.id === tempAttachment.id ? newAttachment : a));
      await onRefresh();
    } catch (err) {
      console.error("Failed to replace attachment:", err);
      // Rollback
      setAttachments(prevAttachments);
      setError(`Failed to replace "${replaceFile.name}". Please try again.`);
      await onRefresh();
    } finally {
      setReplacingId(null);
      setReplaceFile(null);
    }
  };

  // --- Upload New (optimistic with temp file) ---
  const handleUpload = async (): Promise<void> => {
    if (!newFile || !request.id) return;
    setError(null);

    const tempAttachment: Attachment = {
      id: `temp-${Date.now()}`,
      file: URL.createObjectURL(newFile),
      file_name: newFile.name,
      maintenance_request: request.id,
      file_type: newFile.type,
      uploaded_at: new Date().toISOString(),
    };
    // 1. Optimistic: show new file instantly
    const prevAttachments = attachments;
    setAttachments((prev) => [...prev, tempAttachment]);

    try {
      const fileToUpload = newFile;
      const realAttachment = await maintenanceService.uploadAttachment(request.id, fileToUpload, fileToUpload.name);
      // Replace temp with real one
      setAttachments((prev) =>
        prev.map((a) => (a.id === tempAttachment.id ? realAttachment : a))
      );
      await onRefresh();
    } catch (err) {
      console.error("❌ Failed to upload attachment:", err);
      // Rollback
      setAttachments(prevAttachments);
      setError(`Failed to upload "${newFile.name}". Please try again.`);
      await onRefresh();
    } finally {
      setNewFile(null);
    }
  };

  // --- Handle Respond (optimistic append to log) ---
  const handleRespond = (): void => {
    if (!newResponse.trim()) return;
    const now = new Date().toLocaleString(); // Client-side timestamp (backend will override)
    const appendEntry = `\n[${now}] ${currentUser?.username || 'Unknown'} (${currentUser?.role || 'Admin'}): ${newResponse}`;
    const optimisticComments = tempComments + appendEntry;
    setTempComments(optimisticComments); // Preview in log
    const payload: { response: string; assigned_to?: string } = {
      response: newResponse,
      assigned_to: assignedTo || undefined,
    };
    // 1. Close instantly and go back to page 1
    onClose();
    // 2. Optimistic update (if parent supports it)
    updateRequest?.(request.id!, { ...request, comments: optimisticComments, assigned_to: payload.assigned_to });
    // 3. Background request
    maintenanceService
      .respond(request.id!, payload)
      .then((updatedRequest) => {
        setTempComments(updatedRequest.comments || ""); // Sync with server
        onRefresh();
      })
      .catch((err) => {
        console.error("❌ Failed to respond:", err);
        onRefresh(); // Rollback via refresh
      });
    // 4. Local reset
    setNewResponse("");
    setAssignedTo("");
  };

  const parsedComments = parseComments(tempComments);
  const isImage = (type: string) => type.startsWith('image/');

  // Close preview on escape or click outside
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPreviewAttachment(null);
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, []);

  // Cleanup blob URLs on unmount
  useEffect(() => {
    return () => {
      attachments.forEach(att => {
        if (att.file && typeof att.file === 'string' && att.file.startsWith('blob:')) {
          URL.revokeObjectURL(att.file);
        }
      });
    };
  }, [attachments]);

  return (
    <>
      <div className="modal-backdrop">
        <div className="modal">
          <div className="modal-header">
            <h2>
              Maintenance Request Details
              <span className="page-indicator"> {page === 1 ? '(Attachments)' : '(Responses)'}</span>
            </h2>
            <button className="modal-close" onClick={onClose} aria-label="Close modal">
              &times;
            </button>
          </div>
          <div className="modal-content">
            <div className="info-section">
              <p className="reporter-info">
                <strong>Reported by:</strong> {reportedByLoading ? "Loading..." : (reportedBy?.username || "Unknown")}
              </p>
            </div>
            {error && (
              <div className="error-message">
                {error}
              </div>
            )}
            {/* Page 1: Attachments */}
            {page === 1 && (
              <div className="section">
                <h3>Attachments</h3>
                {attachments.length ? (
                  <ul className="attachments-list">
                    {attachments.map((att) => (
                      <li key={att.id} className="attachment-item">
                        <div className="attachment-info">
                          {isImage(att.file_type) ? (
                            <button
                              className="preview-btn"
                              onClick={() => setPreviewAttachment(att)}
                              title="Preview Image"
                            >
                              👁️ {att.file_name}
                            </button>
                          ) : (
                            <a href={getFileSrc(att.file)} target="_blank" rel="noopener noreferrer" className="download-link">
                              📎 {att.file_name}
                            </a>
                          )}
                          <span className="file-type">({att.file_type})</span>
                        </div>
                        <div className="attachment-actions">
                          {replacingId === att.id ? (
                            <>
                              <input
                                type="file"
                                onChange={(e) => setReplaceFile(e.target.files?.[0] ?? null)}
                                className="file-input-replace"
                                style={{ marginRight: '5px' }}
                              />
                              <button
                                className="btn btn-primary btn-small"
                                onClick={() => handleReplaceAttachment(att.id)}
                                disabled={!replaceFile}
                              >
                                Replace
                              </button>
                              <button
                                className="btn btn-secondary btn-small"
                                onClick={() => { setReplacingId(null); setReplaceFile(null); }}
                              >
                                Cancel
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                className="btn btn-primary btn-small"
                                onClick={() => setReplacingId(att.id)}
                                title="Replace File"
                                disabled={replacingId !== null}
                              >
                                Replace
                              </button>
                              <button
                                className="btn btn-danger btn-small"
                                onClick={() => handleDeleteAttachment(att.id, att.id.startsWith('temp-'))}
                                disabled={deletingId === att.id || replacingId !== null}
                                title="Delete"
                              >
                                {deletingId === att.id ? 'Deleting...' : 'Delete'}
                              </button>
                            </>
                          )}
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="no-attachments">No attachments</p>
                )}
                <div className="upload-section">
                  <h4>Add New Attachment</h4>
                  <div className="upload-controls">
                    <input
                      type="file"
                      onChange={(e) => setNewFile(e.target.files?.[0] ?? null)}
                      className="file-input"
                      disabled={replacingId !== null}
                    />
                    <button
                      onClick={handleUpload}
                      disabled={!newFile || replacingId !== null}
                      className="btn btn-primary"
                    >
                      Upload New
                    </button>
                  </div>
                </div>
                <div className="modal-actions">
                  <button className="btn btn-primary" onClick={() => setPage(2)}>
                    Next: Responses
                  </button>
                  <button className="btn btn-secondary" onClick={onClose}>
                    Close
                  </button>
                </div>
              </div>
            )}
            {/* Page 2: Response History & Add Update */}
            {page === 2 && (
              <div className="section">
                <h3>Response History</h3>
                <div className="comments-log">
                  {parsedComments.length > 0 ? (
                    parsedComments.map((entry, index) => (
                      <div key={index} className="comment-entry">
                        <strong>[{entry.timestamp}] {entry.user} ({entry.role}):</strong>
                        <p>{entry.message}</p>
                      </div>
                    ))
                  ) : (
                    <p className="no-responses">No responses yet.</p>
                  )}
                </div>
                <label className="form-label">
                  Add New Response:
                  <textarea
                    value={newResponse}
                    onChange={(e) => setNewResponse(e.target.value)}
                    rows={3}
                    placeholder="Enter your update here..."
                    className="response-textarea"
                  />
                </label>
                <label className="form-label">
                  Assign to:
                  <select
                    value={assignedTo}
                    onChange={(e) => setAssignedTo(e.target.value)}
                    className="assign-select"
                  >
                    <option value="">Unassigned</option>
                    {users.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.username}
                      </option>
                    ))}
                  </select>
                </label>
                <div className="modal-actions">
                  <button className="btn btn-primary" onClick={handleRespond} disabled={!newResponse.trim()}>
                    Submit Update
                  </button>
                  <button className="btn btn-secondary" onClick={() => setPage(1)}>
                    Back: Attachments
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Image Preview Overlay - Renders on top of main modal */}
      {previewAttachment && (
        <div 
          className="image-preview-backdrop" 
          onClick={() => setPreviewAttachment(null)}
          role="dialog"
          aria-label="Image preview"
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
                <p>Preview not available for {previewAttachment.file_type}. <a href={getFileSrc(previewAttachment.file)} target="_blank" rel="noopener noreferrer">Download</a></p>
              </div>
            )}
            <button 
              className="preview-close" 
              onClick={() => setPreviewAttachment(null)} 
              aria-label="Close preview"
            >
              &times;
            </button>
          </div>
        </div>
      )}
    </>
  );
};

export default MaintenanceViewModal;