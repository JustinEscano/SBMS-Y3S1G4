import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class Helpsupportscreen extends StatefulWidget {
  @override
  State<Helpsupportscreen> createState() => _HelpsupportscreenState();
}

class _HelpsupportscreenState extends State<Helpsupportscreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Help & Support',
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
              'Contact Us:',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            _sectionBody(
              "orbit@gmail.com",
            ),
            const SizedBox(height: 20),
            Text(
              'Support:',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            _sectionBody(
              "orbit-support@gmail.com",
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