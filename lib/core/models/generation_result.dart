class GenerationResult {
  const GenerationResult({
    this.b64Json,
    this.imageUrl,
    this.rawResponseValue,
    this.retriedWithSingleImage = false,
  });

  final String? b64Json;
  final String? imageUrl;
  final String? rawResponseValue;
  final bool retriedWithSingleImage;

  bool get hasImageData =>
      (b64Json != null && b64Json!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  GenerationResult copyWith({
    String? b64Json,
    String? imageUrl,
    String? rawResponseValue,
    bool? retriedWithSingleImage,
  }) {
    return GenerationResult(
      b64Json: b64Json ?? this.b64Json,
      imageUrl: imageUrl ?? this.imageUrl,
      rawResponseValue: rawResponseValue ?? this.rawResponseValue,
      retriedWithSingleImage:
          retriedWithSingleImage ?? this.retriedWithSingleImage,
    );
  }
}
