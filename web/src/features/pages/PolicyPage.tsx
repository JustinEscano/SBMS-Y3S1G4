// PolicyPage.tsx - New page for /policy
import React from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css"; // Reuse enhanced CSS

const PolicyPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Privacy Policy" }}>
      <div className="profile-page-container">
        <h2 className="text-xl font-semibold text-white mb-2">Privacy Policy</h2>
        <p className="text-gray-400 mb-4">Our commitment to protecting your data.</p>
        <div className="profile-info">
          <p>Read our full privacy policy here.</p>
          {/* Add policy content */}
        </div>
      </div>
    </PageLayout>
  );
};

export default PolicyPage;