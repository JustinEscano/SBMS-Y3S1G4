import React from "react";
import PageLayout from "./PageLayout";

const AboutPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "About" }}>
      <h1>About Us</h1>
      <p>About information, contacts and legal copy go here.</p>
    </PageLayout>
  );
};

export default AboutPage;
