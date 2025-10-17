import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class Aboutusscreen extends StatefulWidget {
  @override
  State<Aboutusscreen> createState() => _AboutusscreenState();
}

class _AboutusscreenState extends State<Aboutusscreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('About Us',
         style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),),
        backgroundColor: const Color(0xFF1F1E23),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Orbit:',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            _sectionBody(
              'Orbit is a smart platform that monitors room security, energy and maintenance requests to automate building operations'
              'and make facilities more efficient and comfortable. It uses AI for energy optimization, device diagnostic, and room analysis based on real-time data,'
              'letting users monitor everything from a web or mobile app. By simulating IoT devices, Orbit cuts costs, prevents breakdowns, and improves daily life'
              'for occupants through simple, secure controls.',
            ),
            const SizedBox(height: 20),
            Text(
              'LLM Model:',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            _sectionBody(
              "Llama3.1-claude",
            ),
            const SizedBox(height: 20),
            Text(
              'Members:',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            _sectionBody(
              "Project Manager - Escano, Justin Paul Louise C.\n"
              "Lead Developer - Denulan, Ace Philip S.\n"
              "LLM Engineer, Backend Developer - Estrada, Matthew Cymon S.\n"
              "UI/UX Designer - De Guzman. Gemerald\n"
              "Web and Mobile Frontend Developer - Pagasartonga, Peter R.\n"
              "Web Frontend Developer - Sandino, Shierwin Carl\n"
              "LLM Engineer - Manaloto, David Paul\n"
              "Backend Developer - Villegas, Brian Isaac\n"
              "Web and Mobile Frontend Developer - Posadas, Xander\n",
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.cabin(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.cabin(
          fontSize: 14,
          color: const Color(0xFF999898),
          height: 1.5,
        ),
      ),
    );
  }
}