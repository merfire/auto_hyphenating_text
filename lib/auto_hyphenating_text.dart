
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hyphenator_impure/hyphenator.dart';

ResourceLoader? globalLoader;

Future<void> initHyphenation([DefaultResourceLoaderLanguage language = DefaultResourceLoaderLanguage.enUs]) async {
	globalLoader = await DefaultResourceLoader.load(language);
}

class AutoHyphenatingText extends StatelessWidget {
	const AutoHyphenatingText(
		this.text, {
		this.shouldHyphenate,
		this.loader,
		this.style,
		this.strutStyle,
		this.textAlign,
		this.textDirection,
		this.locale,
		this.softWrap,
		this.overflow,
		this.textScaleFactor,
		this.maxLines,
		this.semanticsLabel,
		this.textWidthBasis,
		this.selectionColor,
		super.key,
	});

	final String text;
	final ResourceLoader? loader;
	final bool Function(double totalLineWidth, double lineWidthAlreadyUsed, double currentWordWidth)? shouldHyphenate;
	final TextStyle? style;
	final TextAlign? textAlign;
	final StrutStyle? strutStyle;
	final TextDirection? textDirection;
	final Locale? locale;
	final bool? softWrap;
	final TextOverflow? overflow;
	final double? textScaleFactor;
	final int? maxLines;
	final String? semanticsLabel;
	final TextWidthBasis? textWidthBasis;
	final Color? selectionColor;

	String mergeSyllablesFront(List<String> syllables, int indicesToMergeInclusive) {
		 StringBuffer buffer = StringBuffer();

		 for (int i = 0; i <= indicesToMergeInclusive; i++) {
			 buffer.write(syllables[i]);
		 }

		 // Only write the hyphen if the character is not punctuation
		 String returnString = buffer.toString();
		 if (returnString.isEmpty || !RegExp("\\p{P}", unicode: true).hasMatch(returnString[returnString.length - 1])) {
			 return "$returnString-";
		 }

		 return returnString;
	}

	String mergeSyllablesBack(List<String> syllables, int indicesToMergeInclusive) {
		StringBuffer buffer = StringBuffer();

		for (int i = indicesToMergeInclusive + 1; i < syllables.length; i++) {
			buffer.write(syllables[i]);
		}

		return buffer.toString();
	}

	int? effectiveMaxLines() => overflow == TextOverflow.ellipsis ? 1 : maxLines;

	@override
	Widget build(BuildContext context) {

		double getTextWidth(String text, TextStyle? style, TextDirection? direction, double? scaleFactor) {
			final TextPainter textPainter = TextPainter(
				text: TextSpan(text: text, style: style),
				textScaleFactor: scaleFactor ?? MediaQuery.of(context).textScaleFactor,
				maxLines: 1,
				textDirection: direction ?? Directionality.of(context),
			)..layout();
			return textPainter.size.width;
		}

		int? getLastSyllableIndex(List<String> syllables, double availableSpace, TextStyle? effectiveTextStyle) {

			if (getTextWidth(mergeSyllablesFront(syllables, 0), effectiveTextStyle, textDirection, textScaleFactor) > availableSpace) {
				return null;
			}

			int lowerBound = 0;
			int upperBound = syllables.length;

			while (lowerBound != upperBound - 1) {
				int testIndex = ((lowerBound + upperBound) * 0.5).floor();

				if (getTextWidth(mergeSyllablesFront(syllables, testIndex), effectiveTextStyle, textDirection, textScaleFactor) > availableSpace) {
					upperBound = testIndex;
				} else {
					lowerBound = testIndex;
				}
			}

			return lowerBound;
		}

		final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
		TextStyle? effectiveTextStyle = style;
		if (style == null || style!.inherit) {
			effectiveTextStyle = defaultTextStyle.style.merge(style);
		}
		if (MediaQuery.boldTextOverride(context)) {
			effectiveTextStyle = effectiveTextStyle!.merge(const TextStyle(fontWeight: FontWeight.bold));
		}

		return LayoutBuilder(
				builder: (BuildContext context, BoxConstraints constraints) {

			List<String> words = text.split(" ");
			List<InlineSpan> texts = <InlineSpan>[];

			assert(globalLoader != null, "AutoHyphenatingText not initialized! Remember to call initHyphenation().");
			final Hyphenator hyphenator = Hyphenator(
				resource: loader ?? globalLoader!,
				hyphenateSymbol: '_',
			);

			double singleSpaceWidth = getTextWidth(" ", effectiveTextStyle, textDirection, textScaleFactor);
			double currentLineSpaceUsed = 0;
			int lines = 0;

			double endBuffer = style?.overflow == TextOverflow.ellipsis ? getTextWidth("…", style, textDirection, textScaleFactor) : 0;

			for (int i = 0; i < words.length; i++) {

				double wordWidth = getTextWidth(words[i], effectiveTextStyle, textDirection, textScaleFactor);

				if (currentLineSpaceUsed + wordWidth < constraints.maxWidth - endBuffer) {
					texts.add(TextSpan(text: words[i]));
					currentLineSpaceUsed += wordWidth;
				} else {

					final List<String> syllables = words[i].length == 1 ? <String>[words[i]] : hyphenator.hyphenateWordToList(words[i]);
					final int? syllableToUse = words[i].length == 1 ? null : getLastSyllableIndex(syllables, constraints.maxWidth - currentLineSpaceUsed, effectiveTextStyle);

					if (syllableToUse == null || (shouldHyphenate != null && !shouldHyphenate!(constraints.maxWidth, currentLineSpaceUsed, wordWidth))) {
						if (currentLineSpaceUsed == 0) {
							texts.add(TextSpan(text: words[i]));
							currentLineSpaceUsed += wordWidth;
						} else {
							i--;
							if (texts.last == const TextSpan(text: " ")) {
								texts.removeLast();
							}
							currentLineSpaceUsed = 0;
							lines++;
							if (effectiveMaxLines() != null && lines >= effectiveMaxLines()!) {
								break;
							}
							texts.add(const TextSpan(text: "\n"));
						}
						continue;
					} else {
						texts.add(TextSpan(text: mergeSyllablesFront(syllables, syllableToUse)));
						words.insert(i + 1, mergeSyllablesBack(syllables, syllableToUse));
						currentLineSpaceUsed = 0;
						lines++;
						if (effectiveMaxLines() != null && lines >= effectiveMaxLines()!) {
							break;
						}
						texts.add(const TextSpan(text: "\n"));
						continue;
					}
				}

				if (i != words.length - 1) {
					if (currentLineSpaceUsed + singleSpaceWidth < constraints.maxWidth) {
						texts.add(const TextSpan(text: " "));
						currentLineSpaceUsed += singleSpaceWidth;
					} else {
						if (texts.last == const TextSpan(text: " ")) {
							texts.removeLast();
						}
						currentLineSpaceUsed = 0;
						lines++;
						if (effectiveMaxLines() != null && lines >= effectiveMaxLines()!) {
							break;
						}
						texts.add(const TextSpan(text: "\n"));
					}
				}
			}

			if (overflow == TextOverflow.ellipsis) {
				texts.add(const TextSpan(text: "…"));
			}

			final SelectionRegistrar? registrar = SelectionContainer.maybeOf(context);
			Widget richText = RichText(
				textDirection: textDirection,
				strutStyle: strutStyle,
				locale: locale,
				softWrap: softWrap ?? true,
				overflow: overflow ?? TextOverflow.clip,
				textScaleFactor: textScaleFactor ?? MediaQuery.of(context).textScaleFactor,
				textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
				selectionColor: selectionColor,
				textAlign: textAlign ?? TextAlign.start,
				selectionRegistrar: registrar,
				text: TextSpan(
					style: effectiveTextStyle,
					children: texts,
				),
			);

			if (registrar != null) {
				richText = MouseRegion(
					cursor: SystemMouseCursors.text,
					child: richText,
				);
			}
			return Semantics(
				textDirection: textDirection,
				label: semanticsLabel ?? text,
				child: ExcludeSemantics(
					child: richText,
				),
			);
		});
	}
}
