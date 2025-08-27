import React from "react";
import PageLayout from "./PageLayout";

const UsagePage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Usage" }}>
      <h1>Usage Analytics</h1>
      <p>Usage metrics, charts and filters go here.</p>
    </PageLayout>
  );
};

export default UsagePage;
