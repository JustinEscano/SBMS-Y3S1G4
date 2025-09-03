import React, { useEffect, useMemo, useRef, useState } from "react";
import type { Equipment, EquipmentStatus, EquipmentType, Room } from "../types/dashboardTypes";
import "./Modal.css";

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

const EquipmentModal: React.FC<EquipmentModalProps> = ({
  mode,
  equipment,
  rooms,
  allowedTypes,
  onClose,
  onSubmit,
}) => {
  const [formData, setFormData] = useState<{
    name: string;
    room: string;
    type: EquipmentType;
    status: EquipmentStatus;
    qr_code: string;
    description: string;
  }>({
    name: "",
    room: "",
    type: allowedTypes[0],
    status: "offline",
    qr_code: "",
    description: "",
  });

  const [roomSearch, setRoomSearch] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const [roomError, setRoomError] = useState("");
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Initialize modal data
  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && equipment) {
      setFormData({
        name: equipment.name,
        room: equipment.room,
        type: equipment.type,
        status: equipment.status,
        qr_code: equipment.qr_code ?? "",
        description: (equipment as any).description ?? "",
      });
      const room = rooms.find((r) => r.id === equipment.room);
      setRoomSearch(room ? `${room.name} (Floor ${room.floor})` : "");
    } else if (mode === "add") {
      setFormData((prev) => ({ ...prev, type: allowedTypes[0], status: "offline", description: "" }));
      setRoomSearch("");
    }
  }, [mode, equipment, rooms, allowedTypes]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const filteredRooms = useMemo(
    () =>
      rooms.filter((r) =>
        `${r.name} (Floor ${r.floor})`.toLowerCase().includes(roomSearch.toLowerCase())
      ),
    [rooms, roomSearch]
  );

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (name === "roomSearch") setRoomError("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (mode === "delete" && equipment) {
      onSubmit({ id: equipment.id });
      return;
    }

    if (!roomSearch.trim() && !formData.room) {
      setRoomError("* Please select a room.");
      return;
    }

    let roomId = formData.room;
    if (!roomId) {
      const match = rooms.find(
        (r) => `${r.name} (Floor ${r.floor})`.toLowerCase() === roomSearch.toLowerCase()
      );
      if (match) roomId = match.id;
    }

    const payload: Partial<Equipment> = {
      id: equipment?.id,
      name: formData.name,
      type: formData.type,
      status: formData.status,
      qr_code: formData.qr_code,
      room: roomId,
    };

    onSubmit(payload);
  };

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>
            {mode === "add" && `Add Equipment`}
            {mode === "edit" && "Edit Equipment"}
            {mode === "delete" && "Delete Equipment"}
          </h2>
          <button className="modal-close" onClick={onClose}>&times;</button>
        </div>

        {mode === "delete" ? (
          <div className="modal-content">
            <p>Are you sure you want to delete <strong>{equipment?.name}</strong>?</p>
            <div className="modal-actions">
              <button onClick={handleSubmit} className="delete-btn">Delete</button>
              <button onClick={onClose}>Cancel</button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="modal-content">
            <label>Name:</label>
            <input type="text" name="name" value={formData.name} onChange={handleChange} required />

            <label>Type:</label>
            <select name="type" value={formData.type} onChange={handleChange}>
              {allowedTypes.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>

            <label>Status:</label>
            <select name="status" value={formData.status} onChange={handleChange}>
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>

            <label>QR Code:</label>
            <input type="text" name="qr_code" value={formData.qr_code} onChange={handleChange} />

            <label>Room:</label>
            <div className="dropdown-wrapper" ref={dropdownRef}>
              <input
                type="text"
                value={roomSearch}
                onChange={(e) => { setRoomSearch(e.target.value); setShowDropdown(true); setFormData((prev) => ({ ...prev, room: "" })); setRoomError(""); }}
                onFocus={() => setShowDropdown(true)}
                placeholder="Search room..."
                className={roomError ? "input-error" : ""}
              />
              {roomError && <p className="error-text">{roomError}</p>}

              {showDropdown && (
                <ul className="dropdown">
                  {filteredRooms.map((r) => (
                    <li
                      key={r.id}
                      className={`dropdown-item ${r.id === formData.room ? "selected" : ""}`}
                      onClick={() => { setFormData((prev) => ({ ...prev, room: r.id })); setRoomSearch(`${r.name} (Floor ${r.floor})`); setShowDropdown(false); setRoomError(""); }}
                    >
                      {r.name} (Floor {r.floor})
                    </li>
                  ))}
                  {filteredRooms.length === 0 && <li className="dropdown-item disabled">No rooms found</li>}
                </ul>
              )}
            </div>

            <div className="modal-actions">
              <button type="submit">{mode === "add" ? "Add" : "Save"}</button>
              <button type="button" onClick={onClose}>Cancel</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default EquipmentModal;
