import React from "react";
import PageLayout from "./PageLayout";
import UsageLineChart from "../components/UsageLineChart";

const UsagePage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Usage" }}>
      <h1>Usage Analytics</h1>
      <UsageLineChart />
    </PageLayout>
  );
};

export default UsagePage;
