import React from "react";
import PageLayout from "./PageLayout";
import "./AboutPage.css";

// Editable content variables
const projectName = <strong>Orbit - Smart Building Management Systems™</strong>;
const llm = "Llama3.1-claude";
const members = {
  line1: "Project Manager - Escano, Justin Paul Louise C.",
  line2: "Lead Developer - Denulan, Ace Philip S.",
  line3: "LLM Engineer, Backend Developer - Estrada, Matthew Cymon S.",
  line4: "UI/UX Designer - De Guzman. Gemerald",
  line5: "Web and Mobile Frontend Developer - Pagasartonga, Peter R.",
  line6: "Web Frontend Developer - Sandino, Shierwin Carl",
  line7: "LLM Engineer - Manaloto, David Paul",
  line8: "Backend Developer - Villegas, Brian Isaac",
  line9: "Web and Mobile Frontend Developer - Posadas, Xander",
};

const AboutPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "About" }}>
      <section className="container">
        <h1 className="heading">About Orbit</h1>
        <p style={{ textAlign: 'justify' }}>
          &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;{projectName} is a smart platform that monitors room security, energy and maintenance requests to automate building operations
          and make facilities more efficient and comfortable. It uses AI for energy optimization, device diagnostic, and room analysis based on real-time data,
          letting users monitor everything from a web or mobile app. By simulating IoT devices, Orbit cuts costs, prevents breakdowns, and improves daily life
          for occupants through simple, secure controls.
        </p>

        <h1 className="subheading">LLM Model</h1>
        <p>{llm}</p>

        <h1 className="subheading">Members</h1>
        <ul>
          <li>{members.line1}</li>
          <li>{members.line2}</li>
          <li>{members.line3}</li>
          <li>{members.line4}</li>
          <li>{members.line5}</li>
          <li>{members.line6}</li>
          <li>{members.line7}</li>
          <li>{members.line8}</li>
          <li>{members.line9}</li>
        </ul>

        <h1 className="subheading">Legal</h1>
        <p>
          This app is a registered trademark of {projectName}. <br/>
          Use of this platform is subject to our{" "}
          <a href="/terms">Terms of Service</a> and <a href="/privacy">Privacy Policy</a>.
        </p>
      </section>
    </PageLayout>
  );
};

export default AboutPage;