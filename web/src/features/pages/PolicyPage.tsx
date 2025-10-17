// PolicyPage.tsx - New page for /policy
import React from "react";
import PageLayout from "./PageLayout";
import "./ProfilePage.css"; // Reuse enhanced CSS

const PolicyPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Privacy Policy" }}>
      <div className="profile-page-container max-w-4xl mx-auto p-6">
        <h2 className="text-2xl font-semibold text-white mb-4">Privacy Policy</h2>
        <p className="text-gray-400 mb-6">Our commitment to protecting your data.</p>
        <div className="profile-info space-y-8">
          <section>
            <h3 className="text-lg font-medium text-white mb-3">1. Information We Collect</h3>
            <p className="text-gray-300">We may collect the following information:</p>
            <ul className="list-disc list-inside text-gray-300 space-y-1 ml-4">
              <li>Personal Information (name, email, password)</li>
              <li>Usage Information (activity logs, bookings)</li>
              <li>Building and Facility Data (simulated IoT)</li>
              <li>Device and Technical Data (IP, OS, browser)</li>
              <li>Location Information (if enabled)</li>
            </ul>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">2. Purpose of Data Collection</h3>
            <p className="text-gray-300">Data is collected for academic demonstration:</p>
            <ul className="list-disc list-inside text-gray-300 space-y-1 ml-4">
              <li>To enable system functionality</li>
              <li>To secure user access</li>
              <li>To simulate building automation and reporting</li>
            </ul>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">3. Legal Basis for Processing</h3>
            <p className="text-gray-300">
              Processing is based on consent, aligned with the Data Privacy Act of 2012 (RA 10173).
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">4. Data Sharing and Disclosure</h3>
            <p className="text-gray-300">
              Data may be shared only with authorized team members, hosting providers (e.g., AWS), or as required by law.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">5. Data Storage and Security</h3>
            <p className="text-gray-300">
              Data is stored securely in the cloud with encryption, restricted access, and regular security checks.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">6. Data Retention and Disposal</h3>
            <p className="text-gray-300">
              Data will be retained only for the duration of the project and securely deleted or anonymized afterward.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">7. Rights of Data Subjects</h3>
            <p className="text-gray-300">Users have the right to:</p>
            <ul className="list-disc list-inside text-gray-300 space-y-1 ml-4">
              <li>Be informed</li>
              <li>Access data</li>
              <li>Object or withdraw consent</li>
              <li>Request correction or deletion</li>
            </ul>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">8. Cookies and Similar Technologies</h3>
            <p className="text-gray-300">
              Cookies may be used to maintain sessions and improve navigation.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">9. Third-Party Services</h3>
            <p className="text-gray-300">
              Orbit uses secure third-party cloud services like AWS.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">10. Children’s Privacy</h3>
            <p className="text-gray-300">
              Orbit is not intended for children under 16. Data collected from minors will be deleted immediately.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">11. Contact Information</h3>
            <p className="text-gray-300">
              Project Team: Orbit Smart Building Management System<br />
              Institution: PHINMA University of Pangasinan<br />
              Address: Arellano Street, Dagupan City, 2400, Pangasinan
            </p>
          </section>

          <section>
            <h3 className="text-lg font-medium text-white mb-3">12. Changes to This Privacy Policy</h3>
            <p className="text-gray-300">
              This Privacy Policy may be updated to reflect changes in project requirements.
            </p>
          </section>
        </div>
      </div>
    </PageLayout>
  );
};

export default PolicyPage;