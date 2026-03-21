import React, { useMemo, useState, useCallback, useEffect } from "react";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination";
import MaintenanceModal from "../components/maintenanceModal";
import type { MaintenanceModalMode } from "../components/maintenanceModal";
import { useMaintenanceRequests } from "../hooks/useMaintenance";
import { useEquipment } from "../hooks/useEquipment";
import { userService } from "../services/userService";
import { maintenanceService } from "../services/maintenanceService";
import { useAuth } from "../context/AuthContext"; // Adjust import to your auth hook/context
import type { MaintenanceRequest, User } from "../types/dashboardTypes";
import { useNavigate } from "react-router-dom";
import "../pages/PageStyle.css";

type MaintenanceFormData = Partial<MaintenanceRequest> & {
  id?: string;
  newAttachments?: File[];
  comments?: string;
};

const ITEMS_PER_PAGE = 7;

const STATUS_MAP: Record<string, "pending" | "in_progress" | "resolved"> = {
  pending: "pending",
  in_progress: "in_progress",
  resolved: "resolved",
};

type ModalType = MaintenanceModalMode | null; // Removed "view" since it's now a separate page

const MaintenancePage: React.FC = () => {
  const navigate = useNavigate();
  const { requests, loading, error, updateRequest, deleteRequest, refetch } = useMaintenanceRequests();
  const { equipment } = useEquipment();
  const { } = useAuth(); // Removed unused currentUser

  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selectedRequest, setSelectedRequest] = useState<MaintenanceRequest | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [, setErrorMsg] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return "-";
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return "-";

    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const hh = String(d.getHours()).padStart(2, "0");
    const min = String(d.getMinutes()).padStart(2, "0");

    return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
  };

  // Fetch users
  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const data = await userService.getAll();
        setUsers(data);
      } catch (err) {
        console.error("Failed to fetch users:", err);
      }
    };
    fetchUsers();
  }, []);

  // Modal handlers (removed view handling)
  const openModal = useCallback((type: ModalType, request?: MaintenanceRequest) => {
    setModalType(type);
    setSelectedRequest(request ?? null);
    setErrorMsg(null);
  }, []);

  const closeModal = useCallback(() => {
    setModalType(null);
    setSelectedRequest(null);
    setErrorMsg(null);
  }, []);

  // View handler (new: navigate to view page with ID)
  const handleView = useCallback((request: MaintenanceRequest) => {
    navigate(`/maintenance/${request.id}`);
  }, [navigate]);

  // Filtering + pagination
  const filteredRequests = useMemo(() => {
    const term = search.toLowerCase();
    return requests.filter((r) => {
      const matchesSearch = (r.issue ?? "").toLowerCase().includes(term);
      const matchesStatus =
        statusFilter === "all" ||
        (r.status ?? "").toLowerCase() === statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    });
  }, [requests, search, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredRequests.length / ITEMS_PER_PAGE));
  const paginatedRequests = filteredRequests.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const getUser = useCallback(
    (id?: string | null) => (id ? users.find((u) => u.id === id)?.username || id : "-"),
    [users]
  );
  const getEquipment = useCallback(
    (id?: string) => (id ? equipment.find((e) => e.id === id)?.name || id : "-"),
    [equipment]
  );

  const handleAdd = async (data: MaintenanceFormData): Promise<void> => {
    setSubmitting(true);

    // Optimistic: close modal right away
    closeModal();

    // Optimistic: add placeholder request
    const tempId = `temp-${Date.now()}`;
    const optimisticRequest: MaintenanceRequest = {
      id: tempId,
      user: data.user!,
      equipment: data.equipment!,
      issue: data.issue || "",
      status: data.status ? STATUS_MAP[data.status.toLowerCase()] : "pending",
      scheduled_date: data.scheduled_date || new Date().toISOString().split("T")[0],
      resolved_at: data.resolved_at,
      assigned_to: data.assigned_to || null,
      comments: data.comments || "",
      attachments: []
    };

    updateRequest(tempId, optimisticRequest); // put into state immediately

    try {
      const created = await maintenanceService.create(optimisticRequest);

      if (data.newAttachments?.length) {
        for (const file of data.newAttachments) {
          await maintenanceService.uploadAttachment(created.id!, file);
        }
      }

      // Replace temp with real one
      updateRequest(tempId, created);
    } catch (err) {
      console.error("Failed to create request:", err);
      // Rollback: refetch from server
      await refetch();
    } finally {
      setSubmitting(false);
    }
  };

  // EDIT
  const handleEdit = async (data: MaintenanceFormData): Promise<void> => {
    if (!selectedRequest) return;

    setSubmitting(true);
    closeModal();

    const payload: Partial<MaintenanceRequest> = {
      issue: data.issue,
      status: data.status ? STATUS_MAP[data.status.toLowerCase()] : selectedRequest.status,
      scheduled_date: data.scheduled_date || selectedRequest.scheduled_date,
      resolved_at: data.resolved_at,
      assigned_to: data.assigned_to || null,
      comments: data.comments,
    };

    // Optimistic update
    updateRequest(selectedRequest.id, { ...selectedRequest, ...payload });

    try {
      await maintenanceService.update(selectedRequest.id, payload);

      if (data.newAttachments?.length) {
        for (const file of data.newAttachments) {
          await maintenanceService.uploadAttachment(selectedRequest.id, file);
        }
      }
    } catch (err) {
      console.error("Failed to update request:", err);
      await refetch(); // rollback
    } finally {
      setSubmitting(false);
    }
  };

  // DELETE
  const handleDelete = async (): Promise<void> => {
    if (!selectedRequest) return;

    setSubmitting(true);
    closeModal();

    // Optimistic: remove from UI immediately
    updateRequest(selectedRequest.id, null as any); // or filter out manually

    try {
      await deleteRequest(selectedRequest.id);
    } catch (err) {
      console.error("Failed to delete request:", err);
      await refetch(); // rollback
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance" }}>
      {/* Page Header */}
      <div style={{ marginBottom: '32px', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>Maintenance Requests</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Manage and track equipment maintenance</p>
        </div>
        <button onClick={() => openModal("add")}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', borderRadius: '10px', border: 'none', background: '#3b82f6', color: '#fff', fontSize: '14px', fontWeight: 600, cursor: 'pointer' }}>
          <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v16m8-8H4" /></svg>
          Add Request
        </button>
      </div>

      {/* Filters Card */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '16px', padding: '16px 20px', marginBottom: '16px', display: 'flex', gap: '16px', alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '200px' }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Search</label>
          <div style={{ position: 'relative' }}>
            <svg style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#64748b' }} width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            <input type="text" placeholder="Search requests..." value={search}
              onChange={e => { setSearch(e.target.value); setCurrentPage(1); }}
              style={{ width: '100%', padding: '9px 14px 9px 34px', borderRadius: '10px', border: '1px solid #1d2540', background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none', boxSizing: 'border-box' }}
            />
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flexShrink: 0 }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Status</label>
          <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setCurrentPage(1); }}
            style={{ padding: '9px 14px', borderRadius: '10px', border: '1px solid #1d2540', background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none', flexShrink: 0 }}>
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="in_progress">In Progress</option>
            <option value="resolved">Resolved</option>
          </select>
        </div>
      </div>

      {/* Table Card */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '16px', overflow: 'hidden' }}>
        {/* Table */}
        <div style={{ overflowX: 'auto' }}>
          {loading ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          ) : error ? (
            <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-lg text-red-400 text-center">{error}</div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#0d1022', borderBottom: '1px solid #1d2540' }}>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>User</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Equipment</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Issue</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Status</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Scheduled</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Resolved</th>
                  <th style={{ padding: '14px 16px', textAlign: 'left', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Assigned To</th>
                  <th style={{ padding: '14px 16px', textAlign: 'right', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedRequests.length ? (
                  paginatedRequests.map((req) => (
                    <tr key={req.id} style={{ borderBottom: '1px solid #1d2540', background: '#141828' }}
                      onMouseEnter={e => (e.currentTarget.style.background = '#1a2038')}
                      onMouseLeave={e => (e.currentTarget.style.background = '#141828')}
                    >
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#e2e8f0' }}>{getUser(req.user)}</td>
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#e2e8f0', fontWeight: 500 }}>{getEquipment(req.equipment)}</td>
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#94a3b8', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={req.issue}>{req.issue}</td>
                      <td style={{ padding: '13px 16px' }}>
                        <span style={{
                          display: 'inline-flex', alignItems: 'center', gap: '4px',
                          padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 600,
                          ...((req.status ?? '').toLowerCase() === 'resolved'
                            ? { background: 'rgba(16,185,129,0.15)', color: '#10b981', border: '1px solid rgba(16,185,129,0.3)' }
                            : (req.status ?? '').toLowerCase() === 'in_progress'
                            ? { background: 'rgba(59,130,246,0.15)', color: '#60a5fa', border: '1px solid rgba(59,130,246,0.3)' }
                            : { background: 'rgba(234,179,8,0.15)', color: '#facc15', border: '1px solid rgba(234,179,8,0.3)' })
                        }}>
                          <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'currentColor', flexShrink: 0 }} />
                          {(req.status ?? 'PENDING').replace('_', ' ').toUpperCase()}
                        </span>
                      </td>
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#94a3b8', whiteSpace: 'nowrap' }}>{req.scheduled_date || '-'}</td>
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#94a3b8', whiteSpace: 'nowrap' }}>{formatDate(req.resolved_at) || '-'}</td>
                      <td style={{ padding: '13px 16px', fontSize: '13px', color: '#cbd5e1' }}>{getUser(req.assigned_to)}</td>
                      <td style={{ padding: '13px 16px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                          <button style={{ padding: '5px 12px', background: '#1e293b', border: '1px solid #334155', color: '#e2e8f0', borderRadius: '6px', fontSize: '12px', fontWeight: 500, cursor: 'pointer' }} onClick={() => handleView(req)}>View</button>
                          <button style={{ padding: '5px 12px', background: 'rgba(59,130,246,0.1)', border: '1px solid rgba(59,130,246,0.2)', color: '#60a5fa', borderRadius: '6px', fontSize: '12px', fontWeight: 500, cursor: 'pointer' }} onClick={() => openModal('edit', req)}>Edit</button>
                          <button style={{ padding: '5px 12px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171', borderRadius: '6px', fontSize: '12px', fontWeight: 500, cursor: 'pointer' }} onClick={() => openModal('delete', req)}>Delete</button>
                        </div>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={8} style={{ padding: '48px 20px', textAlign: 'center', color: '#64748b', fontSize: '14px' }}>
                      No maintenance requests found
                      {search && <span style={{ display: 'block', fontSize: '12px', marginTop: '4px' }}>Try adjusting your search filters</span>}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          )}
        </div>

        {/* Modals */}
        {modalType ? (
          <MaintenanceModal
            mode={modalType}
            request={selectedRequest ?? undefined}
            equipments={equipment}
            users={users}
            onClose={closeModal}
            onSubmit={
              modalType === "add" ? handleAdd : modalType === "edit" ? handleEdit : handleDelete
            }
          />
        ) : null}
      </div>

      {!loading && !error && filteredRequests.length > 0 && (
        <div style={{ paddingTop: '16px', display: 'flex', justifyContent: 'center' }}>
          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            onPageChange={setCurrentPage}
            showRange
          />
        </div>
      )}

      {submitting && (
        <div
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            width: "100%",
            height: "100%",
            backgroundColor: "rgba(0,0,0,0.5)",
            zIndex: 999999,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#fff",
            fontSize: "1.2rem",
          }}
        >
          <div className="spinner" />
          <p>Processing…</p>
        </div>
      )}
    </PageLayout>
  );
};

export default MaintenancePage;