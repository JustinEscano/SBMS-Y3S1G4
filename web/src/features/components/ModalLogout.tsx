import React from "react";
import "./ModalLogout.css";
import OrbitLogo from "../../assets/ORBIT.png";
import CompanyNameLogo from "../../assets/Logo-Name.png";

type ModalLogoutProps = {
  isOpen: boolean;
  onClose: () => void;
  onConfirmLogout: () => void;
};

const ModalLogout: React.FC<ModalLogoutProps> = ({ isOpen, onClose, onConfirmLogout }) => {
  if (!isOpen) return null;

  return (
    <div className="modal-logout-overlay">
      <div className="modal-logout-container">
        <div className="modal-logo-container">
          <img src={OrbitLogo} alt="Logo" className="logo-icon" />
          <img src={CompanyNameLogo} alt="Company Name" className="logo-name" />
        </div>
        <p>Are you sure you want to log out?</p>
        <div className="modal-logout-actions">
          <button className="modal-logout-cancel" onClick={onClose}>
            Cancel
          </button>
          <button className="modal-logout-confirm" onClick={onConfirmLogout}>
            Logout
          </button>
        </div>
      </div>
    </div>
  );
};

export default ModalLogout;