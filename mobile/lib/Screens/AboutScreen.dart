import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import './PrivacyPolicyScreen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 50.0,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'About Orbit',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              background: Container(
                color: Color(0xFF1F1E23),
              ),
            ),
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFF1F1E23),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Orbit',
                    style: GoogleFonts.urbanist(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 16),
                  Text(
                    'Orbit - Smart Building Management Systems™ is a smart platform that monitors room security, energy, and maintenance requests to automate building operations and make facilities more efficient and comfortable. It uses AI for energy optimization, device diagnostics, and room analysis based on real-time data, letting users monitor everything from a web or mobile app. By simulating IoT devices, Orbit cuts costs, prevents breakdowns, and improves daily life for occupants through simple, secure controls.',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.justify,
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  Text(
                    'LLM Model',
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Llama3.1-claude',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Members',
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMemberItem('Project Manager - Escano, Justin Paul Louise C.'),
                      _buildMemberItem('Lead Developer - Denulan, Ace Philip S.'),
                      _buildMemberItem('LLM Engineer, Backend Developer - Estrada, Matthew Cymon S.'),
                      _buildMemberItem('UI/UX Designer - De Guzman, Gemerald'),
                      _buildMemberItem('Web and Mobile Frontend Developer - Pagasartonga, Peter R.'),
                      _buildMemberItem('Web Frontend Developer - Sandino, Shierwin Carl'),
                      _buildMemberItem('LLM Engineer - Manaloto, David Paul'),
                      _buildMemberItem('Backend Developer - Villegas, Brian Isaac'),
                      _buildMemberItem('Web and Mobile Frontend Developer - Posadas, Xander'),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Legal',
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'This app is a registered trademark of Orbit - Smart Building Management Systems™.\nUse of this platform is subject to our ',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      children: [
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Terms of Service are coming soon.',
                                    style: GoogleFonts.urbanist(),
                                  ),
                                  backgroundColor: Color(0xFF184BFB),
                                ),
                              );
                            },
                            child: Text(
                              'Terms of Service',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                color: Color(0xFF184BFB),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: ' and '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Privacypolicyscreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                color: Color(0xFF184BFB),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(String member) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: GoogleFonts.urbanist(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              member,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}