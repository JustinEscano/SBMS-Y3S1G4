// HelpSupportPage.tsx - New page for /help-support
import React from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css"; // Reuse enhanced CSS

const HelpSupportPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Help & Support" }}>
      <div className="profile-page-container">
        <h2 className="text-xl font-semibold text-white mb-2">Help & Support</h2>
        <p className="text-gray-400 mb-4">Get assistance with any issues.</p>
        <div className="profile-options">
          <button className="profile-option">
            <span className="option-icon">💬</span>
            <span className="option-label">Contact Support</span>
          </button>
          <button className="profile-option">
            <span className="option-icon">📚</span>
            <span className="option-label">FAQs</span>
          </button>
          <button className="profile-option">
            <span className="option-icon">🎥</span>
            <span className="option-label">Tutorials</span>
          </button>
        </div>
      </div>
    </PageLayout>
  );
};

export default HelpSupportPage;