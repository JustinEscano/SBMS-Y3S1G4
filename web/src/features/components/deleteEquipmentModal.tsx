import React from "react";
import type { Equipment } from "../types/equipmentTypes";
import "./Modal.css";

interface DeleteEquipmentModalProps {
  equipment: Equipment;
  onConfirm: () => void;
  onClose: () => void;
}

const DeleteEquipmentModal: React.FC<DeleteEquipmentModalProps> = ({ equipment, onConfirm, onClose }) => {
  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>Delete Equipment</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="modal-content">
          <p>Are you sure you want to delete <strong>{equipment.name}</strong>?</p>
          <div className="modal-actions">
            <button onClick={onConfirm}>Yes, Delete</button>
            <button onClick={onClose}>Cancel</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DeleteEquipmentModal;
