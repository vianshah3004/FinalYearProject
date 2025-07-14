import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/ml_translation_service.dart';

class LocalizedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const LocalizedText({
    Key? key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : super(key: key);

  @override
  _LocalizedTextState createState() => _LocalizedTextState();
}

class _LocalizedTextState extends State<LocalizedText> {
  String? _translatedText;
  bool _isLoading = true;
  late MLTranslationService _translationService;
  late String _currentLanguage;

  @override
  void initState() {
    super.initState();
    _translationService = MLTranslationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentLanguage = Provider.of<LanguageProvider>(context).currentLanguage;
    _translateText();
  }

  @override
  void didUpdateWidget(LocalizedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLanguage = Provider.of<LanguageProvider>(context).currentLanguage;

    if (oldWidget.text != widget.text || _currentLanguage != newLanguage) {
      _currentLanguage = newLanguage;
      _translateText();
    }
  }

  Future<void> _translateText() async {
    if (_currentLanguage == MLTranslationService.defaultLanguage) {
      setState(() {
        _translatedText = widget.text;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final translation = await _translationService.translateText(
        widget.text,
        _currentLanguage,
      );

      if (mounted) {
        setState(() {
          _translatedText = translation;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error translating text: $e');
      if (mounted) {
        setState(() {
          _translatedText = widget.text; // Fallback to original text
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show original text while loading translation
    final textToShow = _isLoading ? widget.text : (_translatedText ?? widget.text);

    return Text(
      textToShow,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

