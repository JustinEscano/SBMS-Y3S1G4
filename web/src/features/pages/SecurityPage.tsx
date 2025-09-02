import React, { useState } from "react";
import PageLayout from "../pages/PageLayout";
import { useEquipment } from "../hooks/useEquipment";
import type { Equipment } from "../types/equipmentTypes";
import AddEquipmentModal from "../components/addEquipmentModal";
import EditEquipmentModal from "../components/editEquipmentModal";
import DeleteEquipmentModal from "../components/deleteEquipmentModal";
import { equipmentService } from "../services/equipmentService";
import { useRooms } from "../hooks/useRooms";

type ModalType = "add" | "edit" | "delete" | null;

const SecurityPage: React.FC = () => {
  const { equipment, loading, refetch } = useEquipment();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"All" | "Active" | "Inactive">("All");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selected, setSelected] = useState<Equipment | null>(null);
  const { rooms } = useRooms();

  // --- Filter only Security equipment ---
  const securityEquipment = equipment.filter((e) => e.type === "Security");
  const filteredEquipment = securityEquipment.filter((e) => {
    const matchesSearch = e.name.toLowerCase().includes(search.toLowerCase());
    const matchesStatus = statusFilter === "All" ? true : e.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  // --- Modal helpers ---
  const openModal = (type: ModalType, eq?: Equipment) => {
    setModalType(type);
    setSelected(eq || null);
  };

  const closeModal = () => {
    setModalType(null);
    setSelected(null);
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Security" }}>
      <h1>Dashboard &gt; Security</h1>

      <div className="content-container">
        {/* --- Stat Boxes --- */}
        <div className="stats-boxes">
          <div className="stat-box">
            <div className="stat-icon">🔒</div>
            <div className="stat-info">
              <p className="stat-number">{securityEquipment.length}</p>
              <p className="stat-label">Total Security Units</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">✅</div>
            <div className="stat-info">
              <p className="stat-number">
                {securityEquipment.filter((e) => e.status === "Active").length}
              </p>
              <p className="stat-label">Active Units</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">❌</div>
            <div className="stat-info">
              <p className="stat-number">
                {securityEquipment.filter((e) => e.status !== "Active").length}
              </p>
              <p className="stat-label">Inactive Units</p>
            </div>
          </div>
        </div>

        
        <div className="requests-table">
          <h2>Security Table Summary</h2>
          {/* --- Controls --- */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search equipment name"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
          >
            <option value="All">All Status</option>
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
          </select>
          <button className="add-btn" onClick={() => openModal("add")}>
            + Add
          </button>
        </div>

        {/* --- Table --- */}
        {loading ? (
          <p>Loading...</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Room</th>
                <th>Name</th>
                <th>Status</th>
                <th>QR Code</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredEquipment.map((eq) => (
                <tr key={eq.id}>
                  <td>{eq.room}</td>
                  <td>{eq.name}</td>
                  <td>{eq.status}</td>
                  <td>{eq.qr_code}</td>
                  <td>{new Date(eq.created_at).toLocaleDateString()}</td>
                  <td>
                    <button
                      className="edit-btn"
                      onClick={() => openModal("edit", eq)}
                    >
                      Edit
                    </button>
                    <button
                      className="delete-btn"
                      onClick={() => openModal("delete", eq)}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>    
        )}
        </div>
      </div>

      {/* --- Modals --- */}
      {modalType === "add" && (
        <AddEquipmentModal 
        rooms={rooms} 
        onClose={closeModal} 
        onSubmit={async (data) => {
        await equipmentService.create(data as Omit<Equipment, "id" | "created_at">);
        await refetch();
        closeModal();
        }} />
      )}

      {modalType === "edit" && selected && (
        <EditEquipmentModal
          equipment={selected}
          onClose={closeModal}
          onSubmit={async (data) => {
          if (!selected) return;
          const updatedData = { ...data, id: selected.id };
          await equipmentService.update(selected.id, updatedData as Omit<Equipment, "created_at">);
          await refetch();
          closeModal();
        }} />
      )}

      {modalType === "delete" && selected && (
        <DeleteEquipmentModal
          equipment={selected}
          onClose={closeModal}
          onConfirm={async () => {
            if (!selected) return;

            // call delete service
            await equipmentService.remove(selected.id);

            // refresh table
            await refetch();

            // close modal
            closeModal();
          }}
        />
      )}
    </PageLayout>
  );
};

export default SecurityPage;
