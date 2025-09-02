import React from "react";
import PageLayout from "./PageLayout";
import "./AboutPage.css";

// Editable content variables
const companyName = "Orbit Technologies";
const email = "orbit@example.com";
const address = {
  line1: "Arellano St, Downtown District",
  line2: "Dagupan City, 2400 Pangasinan, Philippines",
};

const AboutPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "About" }}>
      <section className="container">
        <h1 className="heading">About Orbit</h1>
        <p>
          <strong>Orbit</strong> is a Smart Building Management System designed to optimize
          facilities through automation, real-time insights, and intelligent control.
        </p>

        <h2 className="subheading">Our Mission</h2>
        <p>We aim to create smarter, more sustainable buildings by integrating IoT, AI, and data analytics into everyday operations.</p>

        <h2 className="subheading">Contact Us</h2>
        <p>
          Reach out at <a href={`mailto:${email}`}>{email}</a> or visit us at:
        </p>
        <address>
          {companyName}
          <br />
          {address.line1}
          <br />
          {address.line2}
        </address>

        <h2 className="subheading">Legal</h2>
        <p>
          Orbit is a registered trademark of {companyName}. Use of this platform is subject to our{" "}
          <a href="/terms">Terms of Service</a> and <a href="/privacy">Privacy Policy</a>.
        </p>
      </section>
    </PageLayout>
  );
};

export default AboutPage;
