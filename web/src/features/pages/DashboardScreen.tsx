import React, { useMemo, useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import Pagination from "../components/Pagination";
import RoomModal from "../components/roomModal";
import type { Room } from "../types/dashboardTypes";
import { roomService } from "../services/roomService";
import { useRooms } from "../hooks/useRooms";
import { Building2, Briefcase, Users, Plus, Search } from "lucide-react";

type RoomModalMode = "add" | "edit" | "delete" | null;
const ITEMS_PER_PAGE = 8;

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

const DashboardScreen: React.FC = () => {
  const { rooms, loading } = useRooms();
  const [localRooms, setLocalRooms] = useState<Room[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<RoomModalMode>(null);
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>();
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => { if (!loading) setLocalRooms(rooms); }, [rooms, loading]);
  useEffect(() => setCurrentPage(1), [search]);

  const filteredRooms = useMemo(() =>
    localRooms.filter(r => r.name.toLowerCase().includes(search.toLowerCase())),
    [localRooms, search]
  );
  const totalPages = Math.ceil(filteredRooms.length / ITEMS_PER_PAGE);
  const paginatedRooms = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredRooms.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredRooms, currentPage]);

  const handleSubmit = async (data: Partial<Room>) => {
    try {
      if (modalMode === "add") {
        const newRoom = await roomService.create(data);
        setLocalRooms(prev => [...prev, newRoom]);
      } else if (modalMode === "edit" && data.id) {
        const updated = await roomService.update(data.id, data);
        setLocalRooms(prev => prev.map(r => r.id === data.id ? { ...r, ...updated } : r));
      } else if (modalMode === "delete" && data.id) {
        await roomService.remove(data.id);
        setLocalRooms(prev => prev.filter(r => r.id !== data.id));
      }
    } catch (err) {
      console.error("Room operation failed:", err);
    } finally {
      setModalMode(null);
      setSelectedRoom(undefined);
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard" }}>
      {/* Page Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>Dashboard</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Rooms overview — manage spaces across the building</p>
        </div>
        <button
          onClick={() => { setModalMode("add"); setSelectedRoom(undefined); }}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', borderRadius: '10px', fontSize: '14px', fontWeight: 600, cursor: 'pointer', border: 'none', background: '#3b82f6', color: '#fff', transition: 'background 0.2s', boxShadow: '0 4px 12px rgba(59,130,246,0.3)' }}
          onMouseEnter={e => e.currentTarget.style.background = '#2563eb'}
          onMouseLeave={e => e.currentTarget.style.background = '#3b82f6'}
        >
          <Plus size={16} /> Add Room
        </button>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '32px' }}>
        <StatCard icon={Building2} label="Total Rooms" value={localRooms.length} color="#3b82f6" />
        <StatCard icon={Briefcase} label="Offices" value={localRooms.filter(r => r.type.toLowerCase() === "office").length} color="#10b981" />
        <StatCard icon={Users} label="Meeting Rooms" value={localRooms.filter(r => r.type.toLowerCase() === "meeting").length} color="#eab308" />
      </div>

      <h2 style={{ fontSize: '22px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px' }}>Room Directory</h2>

      {/* Filters Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '12px', padding: '16px 20px', marginBottom: '16px', display: 'flex', gap: '16px', alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '200px' }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Search</label>
          <div style={{ position: 'relative' }}>
            <Search size={16} style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Search for room"
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ width: '100%', padding: '10px 16px 10px 42px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'all 0.2s', boxSizing: 'border-box' }}
            />
          </div>
        </div>
      </div>

      {/* Table Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '12px', overflow: 'hidden' }}>
        {/* Table */}
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#0d1022', borderBottom: '1px solid #1d2540' }}>
                {['Name', 'Floor', 'Capacity', 'Type', 'Status', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '14px 24px', textAlign: 'center', fontSize: '12px', fontWeight: 700, color: '#f8fafc' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {paginatedRooms.length > 0 ? paginatedRooms.map((room) => (
                <tr key={room.id} style={{ borderBottom: '1px solid #1d2540', background: '#141828' }}>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#e2e8f0', textAlign: 'center' }}>{room.name}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>{room.floor}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>{room.capacity}</td>
                  <td style={{ padding: '14px 24px', fontSize: '13px', color: '#cbd5e1', textAlign: 'center' }}>{room.type.toUpperCase()}</td>
                  <td style={{ padding: '14px 24px', textAlign: 'center' }}>
                    <span style={{ background: 'rgba(5, 150, 105, 0.2)', border: '1px solid rgba(5, 150, 105, 0.4)', padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, color: '#10b981', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                      <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#10b981' }}></span> Online
                    </span>
                  </td>
                  <td style={{ padding: '14px 24px', textAlign: 'center' }}>
                    <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                      <button onClick={() => { setModalMode('edit'); setSelectedRoom(room); }}
                        style={{ padding: '5px 14px', background: 'rgba(59,130,246,0.1)', border: '1px solid rgba(59,130,246,0.2)', color: '#60a5fa', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Edit</button>
                      <button onClick={() => { setModalMode('delete'); setSelectedRoom(room); }}
                        style={{ padding: '5px 14px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Delete</button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan={5} style={{ padding: '48px 20px', textAlign: 'center', color: '#64748b', fontSize: '14px' }}>
                    No rooms found matching your search.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination moved outside */}
      </div>

      <div style={{ paddingTop: '16px', display: 'flex', justifyContent: 'center' }}>
        <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={setCurrentPage} showRange />
      </div>

      {modalMode && (
        <RoomModal
          mode={modalMode}
          room={selectedRoom}
          onClose={() => { setModalMode(null); setSelectedRoom(undefined); }}
          onSubmit={handleSubmit}
        />
      )}
    </PageLayout>
  );
};

export default DashboardScreen;
