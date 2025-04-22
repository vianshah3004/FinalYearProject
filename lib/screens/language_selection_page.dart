import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';
import '../ml_translation_service.dart';
import '../localized_text_widget.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({Key? key}) : super(key: key);

  @override
  _LanguageSelectionPageState createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final MLTranslationService _translationService = MLTranslationService();
  Map<String, bool> _downloadedModels = {};

  @override
  void initState() {
    super.initState();
    _checkDownloadedModels();
  }

  Future<void> _checkDownloadedModels() async {
    for (var language in MLTranslationService.supportedLanguages) {
      final languageCode = language['code'];
      if (languageCode == MLTranslationService.defaultLanguage) continue;

      final isDownloaded = await _translationService.isLanguageDownloaded(languageCode);

      setState(() {
        _downloadedModels[languageCode] = isDownloaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: LocalizedText(
              text: "Select Language",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LocalizedText(
                        text: "Choose Your Preferred Language",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "अपनी पसंदीदा भाषा चुनें",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (languageProvider.isDownloading)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  color: Colors.amber.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Downloading language model for ${_getLanguageName(languageProvider.downloadingLanguage)}...",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: languageProvider.downloadProgress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  itemCount: MLTranslationService.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final language = MLTranslationService.supportedLanguages[index];
                    final languageCode = language['code'];
                    final isSelected = languageCode == languageProvider.currentLanguage;
                    final isDownloaded = _downloadedModels[languageCode] ?? false;

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                              : [],
                        ),
                        child: InkWell(
                          onTap: () async {
                            await languageProvider.changeLanguage(languageCode);

                            // Update downloaded status
                            final isDownloaded = await _translationService.isLanguageDownloaded(languageCode);
                            setState(() {
                              _downloadedModels[languageCode] = isDownloaded;
                            });
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  language['flag'],
                                  style: TextStyle(fontSize: 30),
                                ),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        language['name'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        language['nativeName'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (languageCode != MLTranslationService.defaultLanguage)
                                  Container(
                                    margin: EdgeInsets.only(right: 10),
                                    child: Icon(
                                      isDownloaded ? Icons.download_done : Icons.download,
                                      size: 18,
                                      color: isDownloaded ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    minimumSize: Size(200, 50),
                  ),
                  child: LocalizedText(
                    text: "Apply",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLanguageName(String languageCode) {
    final language = MLTranslationService.supportedLanguages.firstWhere(
          (lang) => lang['code'] == languageCode,
      orElse: () => {'name': languageCode},
    );

    return language['name'];
  }
}

