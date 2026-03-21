import React, { useMemo, useState } from "react";
import PageLayout from "./PageLayout";
import { useEquipment } from "../hooks/useEquipment";
import { useRooms } from "../hooks/useRooms";
import EquipmentModal from "../components/equipmentModal";
import Pagination from "../components/Pagination";
import type { Equipment, EquipmentType, EquipmentStatus, Room } from "../types/dashboardTypes";
import { PAGE_TYPES } from "../constants/constant";
import type { PageType } from "../constants/constant";
import { Cpu, CheckCircle, XCircle, AlertTriangle, Search, Plus, ChevronDown } from "lucide-react";

export const PAGE_TYPE_MAP: Record<PageType, EquipmentType[]> = {
  [PAGE_TYPES.HVAC]: ["monitor", "esp32"],
  [PAGE_TYPES.LIGHTING]: ["actuator", "controller"],
  [PAGE_TYPES.SECURITY]: ["sensor"],
};

type ModalType = "add" | "edit" | "delete" | null;
const ITEMS_PER_PAGE = 8;
type EquipmentWithRoom = Equipment & { roomName?: string; floor?: number | "" };

const statusColors: Record<string, { bg: string; color: string }> = {
  online:      { bg: 'rgba(52,211,153,0.15)',  color: '#34d399' },
  offline:     { bg: 'rgba(239,68,68,0.15)',   color: '#f87171' },
  maintenance: { bg: 'rgba(251,191,36,0.15)',  color: '#fbbf24' },
  error:       { bg: 'rgba(239,68,68,0.15)',   color: '#f87171' },
  default:     { bg: 'rgba(100,116,139,0.15)', color: '#94a3b8' },
};
const getStatusStyle = (s: string) => statusColors[s.toLowerCase()] || statusColors.default;

const StatCard = ({ icon: Icon, label, value, color }: { icon: React.ElementType; label: string; value: number; color: string }) => (
  <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
    <div style={{ position: 'absolute', top: -20, right: -20, width: '100px', height: '100px', borderRadius: '50%', background: color, opacity: 0.08, filter: 'blur(20px)' }} />
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative', zIndex: 1 }}>
      <div>
        <p style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '0 0 8px' }}>{label}</p>
        <p style={{ fontSize: '36px', fontWeight: 900, color: '#ffffff', margin: 0, lineHeight: 1 }}>{value}</p>
      </div>
      <div style={{ width: '52px', height: '52px', borderRadius: '14px', background: '#080b14', border: '1px solid #1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
        <Icon size={24} />
      </div>
    </div>
  </div>
);

interface GenericEquipmentPageProps {
  pageType: PageType;
  icon: string; // kept for compat but unused
}

const GenericEquipmentPage: React.FC<GenericEquipmentPageProps> = ({ pageType }) => {
  const { equipment, loading, addEquipment, updateEquipment, deleteEquipment } = useEquipment();
  const { rooms } = useRooms();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"All" | EquipmentStatus>("All");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selected, setSelected] = useState<Equipment | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [, setErrorMsg] = useState<string | null>(null);

  const allowedTypes = PAGE_TYPE_MAP[pageType] ?? [];

  const filteredByType: Equipment[] = useMemo(() =>
    equipment.filter(e => allowedTypes.includes(e.type))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    [equipment, allowedTypes]
  );

  const mappedEquipment: EquipmentWithRoom[] = useMemo(() =>
    filteredByType.map(eq => {
      const room = rooms.find((r: Room) => r.id === eq.room);
      return { ...eq, roomName: room?.name ?? eq.room, floor: room?.floor ?? "" };
    }), [filteredByType, rooms]
  );

  const filteredEquipment: EquipmentWithRoom[] = useMemo(() => {
    const term = search.toLowerCase();
    return mappedEquipment.filter(e => {
      const matchesSearch = (e.name ?? "").toLowerCase().includes(term) || (e.roomName ?? "").toLowerCase().includes(term) || String(e.floor ?? "").includes(term);
      const matchesStatus = statusFilter === "All" || e.status === statusFilter;
      return matchesSearch && matchesStatus;
    });
  }, [mappedEquipment, search, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredEquipment.length / ITEMS_PER_PAGE));
  const paginatedEquipment = filteredEquipment.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);

  const openModal = (mType: ModalType, eq?: Equipment) => { setModalType(mType); setSelected(eq ?? null); setErrorMsg(null); };
  const closeModal = () => { setModalType(null); setSelected(null); setErrorMsg(null); };

  const formatPayload = (data: Partial<Equipment>): Partial<Equipment> => ({
    name: data.name ?? "", type: data.type as EquipmentType,
    status: (data.status as EquipmentStatus) ?? "offline", qr_code: data.qr_code ?? "", room: data.room,
  });

  const handleAdd = async (data: Partial<Equipment>) => { try { await addEquipment(formatPayload(data)); closeModal(); } catch (err: any) { setErrorMsg(err?.message || "Failed to create."); } };
  const handleEdit = async (data: Partial<Equipment>) => { if (!selected) return; try { await updateEquipment(selected.id, { ...formatPayload(data), id: selected.id }); closeModal(); } catch (err: any) { setErrorMsg(err?.message || "Failed to update."); } };
  const handleDelete = async () => { if (!selected) return; try { await deleteEquipment(selected.id); closeModal(); } catch (err: any) { setErrorMsg(err?.message || "Failed to delete."); } };

  const sectionTitle = pageType.charAt(0).toUpperCase() + pageType.slice(1);

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: pageType }}>
      {/* Page Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>{sectionTitle}</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Monitor and manage {sectionTitle.toLowerCase()} equipment</p>
        </div>
        <button
          onClick={() => openModal("add")}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', borderRadius: '10px', fontSize: '14px', fontWeight: 600, cursor: 'pointer', border: 'none', background: '#3b82f6', color: '#fff', transition: 'background 0.2s', boxShadow: '0 4px 12px rgba(59,130,246,0.3)' }}
          onMouseEnter={e => e.currentTarget.style.background = '#2563eb'}
          onMouseLeave={e => e.currentTarget.style.background = '#3b82f6'}
        >
          <Plus size={16} /> Add Equipment
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '32px' }}>
        <StatCard icon={Cpu} label="Total Units" value={filteredByType.length} color="#3b82f6" />
        <StatCard icon={CheckCircle} label="Online" value={filteredByType.filter(e => e.status === "online").length} color="#10b981" />
        <StatCard icon={XCircle} label="Offline" value={filteredByType.filter(e => e.status === "offline").length} color="#ef4444" />
        <StatCard icon={AlertTriangle} label="In Maintenance" value={filteredByType.filter(e => e.status === "maintenance").length} color="#f59e0b" />
      </div>

      <h2 style={{ fontSize: '22px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px' }}>{sectionTitle} Table</h2>

      {/* Filters Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '12px', padding: '16px 20px', marginBottom: '16px', display: 'flex', gap: '16px', alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '200px' }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Search</label>
          <div style={{ position: 'relative' }}>
            <Search size={16} style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
            <input type="text" placeholder="Search for category" value={search}
              onChange={e => { setSearch(e.target.value); setCurrentPage(1); }}
              style={{ width: '100%', padding: '10px 16px 10px 42px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'all 0.2s', boxSizing: 'border-box' }}
            />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flexShrink: 0 }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Date and Time</label>
          <div style={{ position: 'relative' }}>
            <select style={{ padding: '10px 36px 10px 16px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', appearance: 'none', height: '40px', cursor: 'pointer' }}>
              <option value="day" style={{ background: '#0a0e1a' }}>Day</option>
              <option value="week" style={{ background: '#0a0e1a' }}>Week</option>
              <option value="month" style={{ background: '#0a0e1a' }}>Month</option>
            </select>
            <ChevronDown size={14} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none' }} />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flexShrink: 0 }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Status</label>
          <div style={{ position: 'relative' }}>
            <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value as any); setCurrentPage(1); }}
              style={{ padding: '10px 36px 10px 16px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', appearance: 'none', height: '40px', cursor: 'pointer' }}>
              <option value="All" style={{ background: '#0a0e1a' }}>All Status</option>
              <option value="online" style={{ background: '#0a0e1a' }}>Online</option>
              <option value="offline" style={{ background: '#0a0e1a' }}>Offline</option>
              <option value="maintenance" style={{ background: '#0a0e1a' }}>Maintenance</option>
              <option value="error" style={{ background: '#0a0e1a' }}>Error</option>
            </select>
            <ChevronDown size={14} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none' }} />
          </div>
        </div>
      </div>

      {/* Table Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '12px', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '48px 20px', textAlign: 'center', color: '#64748b', fontSize: '14px' }}>Loading equipment...</div>
        ) : (
          <>
            <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#0d1022', borderBottom: '1px solid #1d2540' }}>
                {['ID', 'Device Name', 'Unit Name', 'Location', 'Temperature', 'Humidity', 'Status', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '14px 24px', textAlign: 'center', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {paginatedEquipment.length > 0 ? paginatedEquipment.map((eq, i) => (
                <tr key={eq.id} style={{ borderBottom: '1px solid #1d2540', background: '#141828' }}>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#e2e8f0', textAlign: 'center' }}>{(currentPage - 1) * ITEMS_PER_PAGE + i + 1}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>{eq.name}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>{eq.type.charAt(0).toUpperCase() + eq.type.slice(1)}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>
                    {eq.floor ? `${eq.floor}${eq.floor === 1 ? 'st' : eq.floor === 2 ? 'nd' : eq.floor === 3 ? 'rd' : 'th'} Floor - ` : ''}{eq.roomName}
                  </td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>NA</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>NA</td>
                  <td style={{ padding: '14px 24px', textAlign: 'center' }}>
                    <span style={{ ...getStatusStyle(eq.status), padding: '4px 10px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: '4px', border: `1px solid ${getStatusStyle(eq.status).color}40` }}>
                      <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: getStatusStyle(eq.status).color }}></span> {eq.status.toUpperCase() === 'MAINTENANCE' ? 'MAINT' : eq.status.toUpperCase()}
                    </span>
                  </td>
                  <td style={{ padding: '14px 24px', textAlign: 'center' }}>
                    <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                      <button onClick={() => openModal('edit', eq)}
                        style={{ padding: '5px 14px', background: 'rgba(59,130,246,0.1)', border: '1px solid rgba(59,130,246,0.2)', color: '#60a5fa', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Edit</button>
                      <button onClick={() => openModal('delete', eq)}
                        style={{ padding: '5px 14px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Delete</button>
                    </div>
                  </td>
                </tr>
                  )) : (
                    <tr><td colSpan={8} style={{ padding: '48px 20px', textAlign: 'center', color: '#64748b', fontSize: '14px' }}>No equipment found.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>

      <div style={{ paddingTop: '16px', display: 'flex', justifyContent: 'center' }}>
        <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={setCurrentPage} showRange />
      </div>

      {modalType && (
        <EquipmentModal rooms={rooms} mode={modalType} equipment={selected || undefined} allowedTypes={allowedTypes} onClose={closeModal}
          onSubmit={modalType === "add" ? handleAdd : modalType === "edit" ? handleEdit : handleDelete}
        />
      )}
    </PageLayout>
  );
};

export default GenericEquipmentPage;
