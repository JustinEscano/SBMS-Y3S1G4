import React, { useEffect, useMemo, useRef, useState } from "react";
import type { Equipment, EquipmentStatus, EquipmentType, Room } from "../types/dashboardTypes";

export type EquipmentModalMode = "add" | "edit" | "delete";

interface EquipmentModalProps {
  mode: EquipmentModalMode;
  equipment?: Equipment;
  rooms: Room[];
  allowedTypes: EquipmentType[];
  onClose: () => void;
  onSubmit: (data: Partial<Equipment>) => void;
}

const STATUS_OPTIONS: EquipmentStatus[] = ["online", "offline", "maintenance", "error"];

/* ── shared style tokens ── */
const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.65)',
    backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', zIndex: 9999, padding: '20px',
  },
  card: {
    background: '#141828', border: '1px solid #1d2540', borderRadius: '20px',
    width: '100%', maxWidth: '520px', overflow: 'hidden',
    boxShadow: '0 24px 64px rgba(0,0,0,0.5)',
  },
  header: {
    background: '#0d1022', borderBottom: '1px solid #1d2540',
    padding: '20px 24px', display: 'flex', alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: { fontSize: '16px', fontWeight: 700, color: '#f8fafc', margin: 0 },
  closeBtn: {
    background: 'transparent', border: 'none', color: '#64748b',
    fontSize: '20px', cursor: 'pointer', lineHeight: 1, padding: '2px 6px', borderRadius: '6px',
  },
  body: { padding: '24px' },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' },
  fieldWrap: { display: 'flex', flexDirection: 'column' as const, gap: '6px' },
  label: { fontSize: '11px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase' as const, letterSpacing: '0.06em' },
  input: {
    padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540',
    background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const,
  },
  select: {
    padding: '10px 14px', borderRadius: '10px', border: '1px solid #1d2540',
    background: '#080c14', color: '#e2e8f0', fontSize: '14px', outline: 'none',
    width: '100%', boxSizing: 'border-box' as const, cursor: 'pointer',
  },
  footer: {
    padding: '16px 24px', borderTop: '1px solid #1d2540',
    display: 'flex', gap: '10px', justifyContent: 'flex-end',
  },
  btnPrimary: {
    padding: '10px 22px', borderRadius: '10px', border: 'none',
    background: '#5b81fb', color: '#fff', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
  btnCancel: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid #334155',
    background: '#1e293b', color: '#e2e8f0', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
  btnDanger: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid rgba(239,68,68,0.35)',
    background: 'rgba(239,68,68,0.12)', color: '#f87171', fontSize: '14px', fontWeight: 600, cursor: 'pointer',
  },
};

const EquipmentModal: React.FC<EquipmentModalProps> = ({ mode, equipment, rooms, allowedTypes, onClose, onSubmit }) => {
  const [formData, setFormData] = useState<{
    name: string; room: string; type: EquipmentType; status: EquipmentStatus; qr_code: string; description: string;
  }>({ name: "", room: "", type: allowedTypes[0], status: "offline", qr_code: "", description: "" });

  const [roomSearch, setRoomSearch] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const [roomError, setRoomError] = useState("");
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && equipment) {
      setFormData({ name: equipment.name, room: equipment.room, type: equipment.type, status: equipment.status, qr_code: equipment.qr_code ?? "", description: (equipment as any).description ?? "" });
      const room = rooms.find(r => r.id === equipment.room);
      setRoomSearch(room ? `${room.name} (Floor ${room.floor})` : "");
    } else if (mode === "add") {
      setFormData(prev => ({ ...prev, type: allowedTypes[0], status: "offline", description: "" }));
      setRoomSearch("");
    }
  }, [mode, equipment, rooms, allowedTypes]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) setShowDropdown(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const filteredRooms = useMemo(() =>
    rooms.filter(r => `${r.name} (Floor ${r.floor})`.toLowerCase().includes(roomSearch.toLowerCase())),
    [rooms, roomSearch]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (mode === "delete" && equipment) { onSubmit({ id: equipment.id }); return; }
    if (!roomSearch.trim() && !formData.room) { setRoomError("* Please select a room."); return; }
    let roomId = formData.room;
    if (!roomId) {
      const match = rooms.find(r => `${r.name} (Floor ${r.floor})`.toLowerCase() === roomSearch.toLowerCase());
      if (match) roomId = match.id;
    }
    onSubmit({ id: equipment?.id, name: formData.name, type: formData.type, status: formData.status, qr_code: formData.qr_code, room: roomId });
  };

  const title = mode === "add" ? "Add Equipment" : mode === "edit" ? "Edit Equipment" : "Delete Equipment";

  return (
    <div style={S.backdrop} onClick={onClose}>
      <div style={S.card} onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div style={S.header}>
          <h2 style={S.title}>{title}</h2>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>

        {/* Delete */}
        {mode === "delete" ? (
          <>
            <div style={{ padding: '32px 24px', textAlign: 'center' }}>
              <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: '24px' }}>
                🗑
              </div>
              <p style={{ color: '#e2e8f0', fontSize: '15px', marginBottom: '6px', fontWeight: 600 }}>
                Delete <span style={{ color: '#f87171' }}>{equipment?.name}</span>?
              </p>
              <p style={{ color: '#64748b', fontSize: '13px', margin: 0 }}>This action cannot be undone.</p>
            </div>
            <div style={S.footer}>
              <button style={S.btnCancel} onClick={onClose}>Cancel</button>
              <button style={S.btnDanger} onClick={handleSubmit}>Delete Equipment</button>
            </div>
          </>
        ) : (
          <form onSubmit={handleSubmit}>
            <div style={S.body}>
              {/* Name */}
              <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                <label style={S.label}>Device Name</label>
                <input style={S.input} type="text" name="name" value={formData.name} onChange={handleChange} placeholder="e.g. Bedroom Sensor" required />
              </div>
              {/* Type + Status */}
              <div style={{ ...S.grid2, marginBottom: '16px' }}>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Type</label>
                  <select style={S.select} name="type" value={formData.type} onChange={handleChange}>
                    {allowedTypes.map(t => <option key={t} value={t} style={{ background: '#0a0e1a' }}>{t.charAt(0).toUpperCase() + t.slice(1)}</option>)}
                  </select>
                </div>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Status</label>
                  <select style={S.select} name="status" value={formData.status} onChange={handleChange}>
                    {STATUS_OPTIONS.map(s => <option key={s} value={s} style={{ background: '#0a0e1a' }}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>)}
                  </select>
                </div>
              </div>
              {/* QR Code */}
              <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                <label style={S.label}>QR Code</label>
                <input style={S.input} type="text" name="qr_code" value={formData.qr_code} onChange={handleChange} placeholder="Optional QR identifier" />
              </div>
              {/* Room searchable dropdown */}
              <div style={S.fieldWrap} ref={dropdownRef}>
                <label style={S.label}>Room</label>
                <div style={{ position: 'relative' }}>
                  <input
                    style={{ ...S.input, borderColor: roomError ? 'rgba(239,68,68,0.5)' : '#1d2540' }}
                    type="text"
                    value={roomSearch}
                    onChange={e => { setRoomSearch(e.target.value); setShowDropdown(true); setFormData(prev => ({ ...prev, room: "" })); setRoomError(""); }}
                    onFocus={() => setShowDropdown(true)}
                    placeholder="Search room..."
                  />
                  {roomError && <p style={{ color: '#f87171', fontSize: '12px', marginTop: '4px' }}>{roomError}</p>}
                  {showDropdown && (
                    <div style={{ position: 'absolute', top: 'calc(100% + 4px)', left: 0, right: 0, background: '#141828', border: '1px solid #1d2540', borderRadius: '10px', maxHeight: '180px', overflowY: 'auto', zIndex: 100, boxShadow: '0 8px 24px rgba(0,0,0,0.4)' }}>
                      {filteredRooms.map(r => (
                        <div
                          key={r.id}
                          style={{ padding: '10px 14px', cursor: 'pointer', fontSize: '13px', color: r.id === formData.room ? '#60a5fa' : '#e2e8f0', background: r.id === formData.room ? 'rgba(59,130,246,0.1)' : 'transparent' }}
                          onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.04)')}
                          onMouseLeave={e => (e.currentTarget.style.background = r.id === formData.room ? 'rgba(59,130,246,0.1)' : 'transparent')}
                          onClick={() => { setFormData(prev => ({ ...prev, room: r.id })); setRoomSearch(`${r.name} (Floor ${r.floor})`); setShowDropdown(false); setRoomError(""); }}
                        >
                          {r.name} <span style={{ color: '#64748b' }}>(Floor {r.floor})</span>
                        </div>
                      ))}
                      {filteredRooms.length === 0 && <div style={{ padding: '10px 14px', color: '#64748b', fontSize: '13px' }}>No rooms found</div>}
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div style={S.footer}>
              <button type="button" style={S.btnCancel} onClick={onClose}>Cancel</button>
              <button type="submit" style={S.btnPrimary}>{mode === "add" ? "Add Equipment" : "Save Changes"}</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default EquipmentModal;
