// PolicyPage.tsx - New page for /policy
import React from "react";
import PageLayout from "./PageLayout";
import { ShieldAlert } from "lucide-react";

const PolicyPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Privacy Policy" }}>
      <div className="max-w-4xl mx-auto py-8">
        <div className="text-center mb-12">
          <div className="w-16 h-16 rounded-full bg-blue-500/10 flex items-center justify-center mx-auto mb-6">
            <ShieldAlert className="w-8 h-8 text-blue-400" />
          </div>
          <h2 className="text-3xl font-bold text-white mb-3">Privacy Policy</h2>
          <p className="text-gray-400 text-lg">Our commitment to protecting your data and privacy.</p>
        </div>

        <div className="bg-[#0f172a] border border-gray-700/50 rounded-2xl p-8 sm:p-10 shadow-xl">
          <div className="prose prose-invert prose-blue max-w-none space-y-10">
            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">1.</span> Information We Collect
              </h3>
              <p className="text-gray-300 mb-3">We may collect the following information:</p>
              <ul className="list-disc list-outside text-gray-300 space-y-2 ml-5 marker:text-blue-500">
                <li><strong className="text-gray-200">Personal Information</strong> (name, email, password)</li>
                <li><strong className="text-gray-200">Usage Information</strong> (activity logs, bookings)</li>
                <li><strong className="text-gray-200">Building and Facility Data</strong> (simulated IoT)</li>
                <li><strong className="text-gray-200">Device and Technical Data</strong> (IP, OS, browser)</li>
                <li><strong className="text-gray-200">Location Information</strong> (if enabled)</li>
              </ul>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">2.</span> Purpose of Data Collection
              </h3>
              <p className="text-gray-300 mb-3">Data is collected for academic demonstration:</p>
              <ul className="list-disc list-outside text-gray-300 space-y-2 ml-5 marker:text-blue-500">
                <li>To enable system functionality</li>
                <li>To secure user access</li>
                <li>To simulate building automation and reporting</li>
              </ul>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">3.</span> Legal Basis for Processing
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Processing is based on consent, aligned with the Data Privacy Act of 2012 (RA 10173).
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">4.</span> Data Sharing and Disclosure
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Data may be shared only with authorized team members, hosting providers (e.g., AWS), or as required by law.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">5.</span> Data Storage and Security
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Data is stored securely in the cloud with encryption, restricted access, and regular security checks.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">6.</span> Data Retention and Disposal
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Data will be retained only for the duration of the project and securely deleted or anonymized afterward.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">7.</span> Rights of Data Subjects
              </h3>
              <p className="text-gray-300 mb-3">Users have the right to:</p>
              <ul className="list-disc list-outside text-gray-300 space-y-2 ml-5 marker:text-blue-500">
                <li>Be informed</li>
                <li>Access data</li>
                <li>Object or withdraw consent</li>
                <li>Request correction or deletion</li>
              </ul>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">8.</span> Cookies and Similar Technologies
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Cookies may be used to maintain sessions and improve navigation.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">9.</span> Third-Party Services
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Orbit uses secure third-party cloud services like AWS.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">10.</span> Children’s Privacy
              </h3>
              <p className="text-gray-300 leading-relaxed">
                Orbit is not intended for children under 16. Data collected from minors will be deleted immediately.
              </p>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">11.</span> Contact Information
              </h3>
              <div className="bg-[#1e293b] rounded-lg p-6 border border-gray-700/50">
                <p className="text-gray-300 leading-relaxed">
                  <strong className="text-white block mb-2">Project Team: Orbit Smart Building Management System</strong>
                  <span className="block mb-1">Institution: PHINMA University of Pangasinan</span>
                  <span className="block">Address: Arellano Street, Dagupan City, 2400, Pangasinan</span>
                </p>
              </div>
            </section>

            <section>
              <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
                <span className="text-blue-500">12.</span> Changes to This Privacy Policy
              </h3>
              <p className="text-gray-300 leading-relaxed">
                This Privacy Policy may be updated to reflect changes in project requirements.
              </p>
            </section>
          </div>
        </div>
      </div>
    </PageLayout>
  );
};

export default PolicyPage;