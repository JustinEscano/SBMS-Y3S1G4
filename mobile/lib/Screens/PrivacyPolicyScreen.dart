import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Config/api.dart';
import '../Services/auth_service.dart';
import '../Widgets/RoomManagementWidgets.dart';

class Privacypolicyscreen extends StatefulWidget {
  @override
  State<Privacypolicyscreen> createState() => _PrivacypolicyscreenState();
}

class _PrivacypolicyscreenState extends State<Privacypolicyscreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Privacy Policy',
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
              'Privacy Policy for Orbit',
              style: GoogleFonts.urbanist(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Main font color
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('1. Information We Collect'),
            _sectionBody(
              'We may collect the following information:\n'
              '- Personal Information (name, email, password)\n'
              '- Usage Information (activity logs, bookings)\n'
              '- Building and Facility Data (simulated IoT)\n'
              '- Device and Technical Data (IP, OS, browser)\n'
              '- Location Information (if enabled)',
            ),

            _sectionTitle('2. Purpose of Data Collection'),
            _sectionBody(
              'Data is collected for academic demonstration:\n'
              '- To enable system functionality\n'
              '- To secure user access\n'
              '- To simulate building automation and reporting',
            ),

            _sectionTitle('3. Legal Basis for Processing'),
            _sectionBody(
              'Processing is based on consent, aligned with the '
              'Data Privacy Act of 2012 (RA 10173).',
            ),

            _sectionTitle('4. Data Sharing and Disclosure'),
            _sectionBody(
              'Data may be shared only with authorized team members, '
              'hosting providers (e.g., AWS), or as required by law.',
            ),

            _sectionTitle('5. Data Storage and Security'),
            _sectionBody(
              'Data is stored securely in the cloud with encryption, '
              'restricted access, and regular security checks.',
            ),

            _sectionTitle('6. Data Retention and Disposal'),
            _sectionBody(
              'Data will be retained only for the duration of the project '
              'and securely deleted or anonymized afterward.',
            ),

            _sectionTitle('7. Rights of Data Subjects'),
            _sectionBody(
              'Users have the right to:\n'
              '- Be informed\n'
              '- Access data\n'
              '- Object or withdraw consent\n'
              '- Request correction or deletion',
            ),

            _sectionTitle('8. Cookies and Similar Technologies'),
            _sectionBody(
              'Cookies may be used to maintain sessions and improve navigation.',
            ),

            _sectionTitle('9. Third-Party Services'),
            _sectionBody(
              'Orbit uses secure third-party cloud services like AWS.',
            ),

            _sectionTitle('10. Children’s Privacy'),
            _sectionBody(
              'Orbit is not intended for children under 16. Data collected '
              'from minors will be deleted immediately.',
            ),

            _sectionTitle('11. Contact Information'),
            _sectionBody(
              'Project Team: Orbit Smart Building Management System\n'
              'Institution: PHINMA University of Pangasinan\n'
              'Address: Arellano Street, Dagupan City, 2400, Pangasinan ',
            ),

            _sectionTitle('12. Changes to This Privacy Policy'),
            _sectionBody(
              'This Privacy Policy may be updated to reflect changes '
              'in project requirements.',
            ),

            const SizedBox(height: 20),
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