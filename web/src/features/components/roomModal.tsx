import React, { useState, useEffect } from "react";
import type { Room } from "../types/dashboardTypes";

export type RoomModalMode = "add" | "edit" | "delete";

interface RoomModalProps {
  mode: RoomModalMode;
  room?: Room;
  onClose: () => void;
  onSubmit: (data: Partial<Room>) => void;
}

/* ── shared inline-style tokens ── */
const S = {
  backdrop: {
    position: 'fixed' as const, inset: 0, background: 'rgba(0,0,0,0.65)',
    backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
    justifyContent: 'center', zIndex: 9999, padding: '20px',
  },
  card: {
    background: '#141828', border: '1px solid #1d2540', borderRadius: '20px',
    width: '100%', maxWidth: '480px', overflow: 'hidden',
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
    fontSize: '20px', cursor: 'pointer', lineHeight: 1, padding: '2px 6px',
    borderRadius: '6px',
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
    background: '#5b81fb', color: '#fff', fontSize: '14px',
    fontWeight: 600, cursor: 'pointer',
  },
  btnCancel: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid #334155',
    background: '#1e293b', color: '#e2e8f0', fontSize: '14px',
    fontWeight: 600, cursor: 'pointer',
  },
  btnDanger: {
    padding: '10px 22px', borderRadius: '10px', border: '1px solid rgba(239,68,68,0.35)',
    background: 'rgba(239,68,68,0.12)', color: '#f87171', fontSize: '14px',
    fontWeight: 600, cursor: 'pointer',
  },
};

const RoomModal: React.FC<RoomModalProps> = ({ mode, room, onClose, onSubmit }) => {
  const [formData, setFormData] = useState({ name: "", floor: "", capacity: "", type: "" });

  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && room) {
      setFormData({
        name: room.name,
        floor: room.floor.toString(),
        capacity: room.capacity?.toString() ?? "",
        type: room.type ?? "",
      });
    } else {
      setFormData({ name: "", floor: "", capacity: "", type: "" });
    }
  }, [mode, room]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (mode === "add") {
      onSubmit({ name: formData.name, floor: Number(formData.floor), capacity: Number(formData.capacity) || 0, type: formData.type });
    } else if (mode === "edit" && room) {
      onSubmit({ id: room.id, name: formData.name, floor: Number(formData.floor), capacity: Number(formData.capacity) || 0, type: formData.type });
    } else if (mode === "delete" && room) {
      onSubmit({ id: room.id });
    }
  };

  const title = mode === "add" ? "Add Room" : mode === "edit" ? "Edit Room" : "Delete Room";

  return (
    <div style={S.backdrop} onClick={onClose}>
      <div style={S.card} onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div style={S.header}>
          <h2 style={S.title}>{title}</h2>
          <button style={S.closeBtn} onClick={onClose}>×</button>
        </div>

        {/* Delete confirmation */}
        {mode === "delete" ? (
          <>
            <div style={{ padding: '32px 24px', textAlign: 'center' }}>
              <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: '24px' }}>
                🗑
              </div>
              <p style={{ color: '#e2e8f0', fontSize: '15px', marginBottom: '6px', fontWeight: 600 }}>
                Delete <span style={{ color: '#f87171' }}>{room?.name}</span>?
              </p>
              <p style={{ color: '#64748b', fontSize: '13px', margin: 0 }}>
                Floor {room?.floor} — this action cannot be undone.
              </p>
            </div>
            <div style={S.footer}>
              <button style={S.btnCancel} onClick={onClose}>Cancel</button>
              <button style={S.btnDanger} onClick={handleSubmit}>Delete Room</button>
            </div>
          </>
        ) : (
          <form onSubmit={handleSubmit}>
            <div style={S.body}>
              {/* Row 1: Name (full width) */}
              <div style={{ ...S.fieldWrap, marginBottom: '16px' }}>
                <label style={S.label}>Room Name</label>
                <input style={S.input} type="text" name="name" value={formData.name} onChange={handleChange} placeholder="e.g. Server Room A" required />
              </div>
              {/* Row 2: Floor + Capacity */}
              <div style={{ ...S.grid2, marginBottom: '16px' }}>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Floor</label>
                  <input style={S.input} type="number" name="floor" value={formData.floor} onChange={handleChange} placeholder="1" required />
                </div>
                <div style={S.fieldWrap}>
                  <label style={S.label}>Capacity</label>
                  <input style={S.input} type="number" name="capacity" value={formData.capacity} onChange={handleChange} placeholder="0" />
                </div>
              </div>
              {/* Row 3: Type */}
              <div style={S.fieldWrap}>
                <label style={S.label}>Type</label>
                <select style={S.select} name="type" value={formData.type} onChange={handleChange} required>
                  <option value="">Select type</option>
                  <option value="office">Office</option>
                  <option value="lab">Laboratory</option>
                  <option value="meeting">Meeting Room</option>
                  <option value="storage">Storage</option>
                  <option value="corridor">Corridor</option>
                  <option value="utility">Utility</option>
                </select>
              </div>
            </div>
            <div style={S.footer}>
              <button type="button" style={S.btnCancel} onClick={onClose}>Cancel</button>
              <button type="submit" style={S.btnPrimary}>{mode === "add" ? "Add Room" : "Save Changes"}</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default RoomModal;
