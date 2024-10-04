import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart' hide compute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../flutter_svg.dart' show svg;
import 'default_theme.dart';
import 'utilities/compute.dart';
import 'utilities/file.dart';

@immutable
class SvgTheme {
  /// Instantiates an SVG theme with the given [currentColor] and [fontSize].
  ///
  /// Defaults [fontSize] to 14, and calculates [xHeight] as half of the [fontSize].
  ///
  /// WARNING: If this codebase ever decides to default the font size to something
  /// based on the BuildContext, caching logic will need to be updated. The font size
  /// can temporarily change during route transitions, affecting performance.
  const SvgTheme({
    this.currentColor = const Color(0xFF000000),
    this.fontSize = 14,
    double? xHeight,
  }) : xHeight = xHeight ?? fontSize / 2;

  /// The default color applied to SVG elements that inherit the color property.
  /// See: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#currentcolor_keyword
  final Color currentColor;

  /// The font size used when calculating em units of SVG elements.
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units
  final double fontSize;

  /// The x-height (corpus size) of the font used when calculating ex units of SVG elements.
  /// Defaults to half of [fontSize] if not provided.
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units,
  /// https://en.wikipedia.org/wiki/X-height
  final double xHeight;

  /// Converts this [SvgTheme] to a [vg.SvgTheme].
  vg.SvgTheme toVgTheme() {
    return vg.SvgTheme(
      currentColor: vg.Color(currentColor.value),
      fontSize: fontSize,
      xHeight: xHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true; // Check for reference equality first
    if (other.runtimeType != runtimeType) return false;

    return other is SvgTheme &&
        currentColor == other.currentColor &&
        fontSize == other.fontSize &&
        xHeight == other.xHeight;
  }

  @override
  int get hashCode => Object.hash(currentColor, fontSize, xHeight);

  @override
  String toString() =>
      'SvgTheme(currentColor: $currentColor, fontSize: $fontSize, xHeight: $xHeight)';
}

@immutable
abstract class ColorMapper {
  /// Allows const constructors on subclasses.
  const ColorMapper();

  /// Returns a new color to use in place of [color] during SVG parsing.
  ///
  /// The SVG parser will call this method each time it encounters a color value
  /// in the SVG. This allows for dynamic color substitution based on the context.
  ///
  /// - [id]: An optional identifier for the current element being parsed.
  /// - [elementName]: The name of the SVG element currently being parsed.
  /// - [attributeName]: The name of the attribute where the color is specified.
  /// - [color]: The original color value that needs to be substituted.
  ///
  /// Implementing subclasses should provide specific logic to determine
  /// the substitute color based on the provided parameters.
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  );
}

class _DelegateVgColorMapper extends vg.ColorMapper {
  /// Creates an instance of [_DelegateVgColorMapper].
  ///
  /// Takes a [colorMapper] instance that will be used for delegating color
  /// substitutions during SVG parsing.
  _DelegateVgColorMapper(this.colorMapper);

  /// The [ColorMapper] instance that defines the color substitution logic.
  final ColorMapper colorMapper;

  /// Delegates the color substitution to the provided [colorMapper].
  ///
  /// Overrides the [substitute] method from [vg.ColorMapper] to perform color
  /// substitution using the provided [colorMapper]. This method takes in
  /// parameters related to the current SVG context and calls the substitute
  /// method on [colorMapper].
  ///
  /// - [id]: An optional identifier for the current SVG element.
  /// - [elementName]: The name of the SVG element being processed.
  /// - [attributeName]: The name of the attribute where the color is defined.
  /// - [color]: The original color as a [vg.Color] that needs substitution.
  ///
  /// Returns a new [vg.Color] after applying the substitution logic.
  @override
  vg.Color substitute(
      String? id, String elementName, String attributeName, vg.Color color) {
    // Delegate color substitution to the provided ColorMapper instance.
    final Color substituteColor = colorMapper.substitute(
        id, elementName, attributeName, Color(color.value));

    // Ensure the substitute color is valid; you may add error handling here if needed.
    return vg.Color(substituteColor.value);
  }
}

@immutable
abstract class SvgLoader<T> extends BytesLoader {
  /// Creates an instance of [SvgLoader].
  ///
  /// Takes an optional [theme] to determine currentColor and font sizing
  /// attributes and an optional [colorMapper] to transform colors from
  /// the SVG.
  const SvgLoader({
    this.theme,
    this.colorMapper,
  });

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme? theme;

  /// The [ColorMapper] used to transform colors from the SVG, if any.
  final ColorMapper? colorMapper;

  /// Provides the SVG string representation for a given [message].
  ///
  /// This method will be called in [compute] with the result of
  /// [prepareMessage]. Subclasses must implement this method to provide
  /// the SVG string.
  @protected
  String provideSvg(T? message);

  /// Prepares the message for SVG processing.
  ///
  /// This method will be called before processing the SVG and can be
  /// overridden by subclasses to provide specific message preparation
  /// logic. The default implementation returns a synchronous Future with null.
  @protected
  Future<T?> prepareMessage(BuildContext? context) =>
      SynchronousFuture<T?>(null);

  /// Returns the SVG theme.
  ///
  /// This method retrieves the theme, checking the provided theme
  /// first, and then falling back to the default theme if no theme is provided.
  @visibleForTesting
  @protected
  SvgTheme getTheme(BuildContext? context) {
    if (theme != null) {
      return theme!;
    }
    if (context != null) {
      final SvgTheme? defaultTheme = DefaultSvgTheme.of(context)?.theme;
      if (defaultTheme != null) {
        return defaultTheme;
      }
    }
    return const SvgTheme();
  }

  /// Loads the SVG data as bytes.
  Future<ByteData> _load(BuildContext? context) async {
    final SvgTheme theme = getTheme(context);
    try {
      T? message = await prepareMessage(context);
      return compute((T? message) {
        return vg
            .encodeSvg(
              xml: provideSvg(message),
              theme: theme.toVgTheme(),
              colorMapper: colorMapper == null
                  ? null
                  : _DelegateVgColorMapper(colorMapper!),
              debugName: 'Svg Loader - Encoding SVG',
              enableClippingOptimizer: false,
              enableMaskingOptimizer: false,
              enableOverdrawOptimizer: false,
            )
            .buffer
            .asByteData();
      }, message, debugLabel: 'Svg Loader - Load Bytes');
    } catch (e) {
      // Handle any errors during SVG loading gracefully.
      throw Exception('Failed to load SVG: $e');
    }
  }

  /// Loads the SVG bytes, utilizing caching to avoid unnecessary
  /// repeated loads.
  ///
  /// This method intentionally avoids using `await` to help tests
  /// and reduce unnecessary event loop turns.
  @override
  Future<ByteData> loadBytes(BuildContext? context) {
    return svg.cache.putIfAbsent(cacheKey(context), () => _load(context));
  }

  @override
  SvgCacheKey cacheKey(BuildContext? context) {
    final SvgTheme theme = getTheme(context);
    return SvgCacheKey(keyData: this, theme: theme, colorMapper: colorMapper);
  }
}

@immutable
class SvgCacheKey {
  /// Creates an instance of [SvgCacheKey].
  ///
  /// The [keyData] is required for caching and should uniquely identify
  /// the SVG content. The [colorMapper] is optional and can be used
  /// to transform colors in the SVG. The [theme] is also optional
  /// and provides context for the current color and font sizing.
  const SvgCacheKey({
    required this.keyData,
    this.colorMapper,
    this.theme,
  });

  /// The theme for this cached SVG.
  final SvgTheme? theme;

  /// The unique identifier for this SVG, typically the loader itself.
  final Object keyData;

  /// The optional [ColorMapper] used to transform colors from the SVG.
  final ColorMapper? colorMapper;

  @override
  int get hashCode => Object.hash(theme, keyData, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgCacheKey &&
        other.theme == theme &&
        other.keyData == keyData &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() {
    return 'SvgCacheKey(theme: $theme, keyData: $keyData, colorMapper: $colorMapper)';
  }
}

class SvgStringLoader extends SvgLoader<void> {
  /// Creates an instance of [SvgStringLoader].
  ///
  /// The [_svg] parameter is the SVG string to be loaded. The optional
  /// [theme] and [colorMapper] can be provided for customization.
  const SvgStringLoader(
    this._svg, {
    super.theme,
    super.colorMapper,
  });

  /// The SVG string to be loaded.
  final String _svg;

  /// Provides the SVG string for loading.
  @override
  String provideSvg(void message) {
    return _svg;
  }

  @override
  int get hashCode => Object.hash(_svg, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgStringLoader &&
        other._svg == _svg &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() {
    return 'SvgStringLoader(svg: $_svg, theme: $theme, colorMapper: $colorMapper)';
  }
}

class SvgBytesLoader extends SvgLoader<void> {
  /// Creates an instance of [SvgBytesLoader].
  ///
  /// The [bytes] parameter should contain UTF-8 encoded XML data representing the SVG.
  const SvgBytesLoader(
    this.bytes, {
    super.theme,
    super.colorMapper,
  });

  /// The UTF-8 encoded XML bytes.
  final Uint8List bytes;

  /// Provides the SVG string for loading by decoding the byte array.
  ///
  /// If the bytes cannot be decoded, it will return an empty string or
  /// handle the error gracefully depending on the implementation.
  @override
  String provideSvg(void message) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      // Log or handle the error as appropriate
      return ''; // Returning an empty string as a fallback
    }
  }

  @override
  int get hashCode => Object.hash(bytes, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgBytesLoader &&
        other.bytes == bytes &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() {
    return 'SvgBytesLoader(bytes: $bytes, theme: $theme, colorMapper: $colorMapper)';
  }
}

class SvgFileLoader extends SvgLoader<void> {
  /// Creates an instance of [SvgFileLoader].
  ///
  /// The [file] parameter should point to a file containing valid SVG data.
  const SvgFileLoader(
    this.file, {
    super.theme,
    super.colorMapper,
  });

  /// The file containing the SVG data to decode and render.
  final File file;

  /// Provides the SVG string by reading the file's bytes and decoding them.
  ///
  /// If the file cannot be read or the data is invalid, it will return an
  /// empty string or handle the error gracefully depending on the implementation.
  @override
  String provideSvg(void message) {
    try {
      final Uint8List bytes = file.readAsBytesSync();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      // Log or handle the error as appropriate
      return ''; // Returning an empty string as a fallback
    }
  }

  @override
  int get hashCode => Object.hash(file.path, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgFileLoader &&
        other.file.path == file.path &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() {
    return 'SvgFileLoader(file: ${file.path}, theme: $theme, colorMapper: $colorMapper)';
  }
}

@immutable
class _AssetByteLoaderCacheKey {
  /// Creates an instance of [_AssetByteLoaderCacheKey].
  ///
  /// The [assetName] represents the name of the asset to be loaded.
  /// The [packageName] is optional and specifies the package from which
  /// the asset is loaded.
  /// The [assetBundle] is the bundle that contains the asset data.
  const _AssetByteLoaderCacheKey(
    this.assetName,
    this.packageName,
    this.assetBundle,
  );

  /// The name of the asset to be loaded.
  final String assetName;

  /// The name of the package where the asset is located. This is optional.
  final String? packageName;

  /// The asset bundle that contains the asset data.
  final AssetBundle assetBundle;

  @override
  int get hashCode => Object.hash(assetName, packageName, assetBundle);

  @override
  bool operator ==(Object other) {
    return other is _AssetByteLoaderCacheKey &&
        other.assetName == assetName &&
        other.assetBundle == assetBundle &&
        other.packageName == packageName;
  }

  @override
  String toString() {
    return 'AssetByteLoaderCacheKey(assetName: $assetName, '
        'packageName: ${packageName ?? "none"}, '
        'assetBundle: $assetBundle)';
  }
}

class SvgAssetLoader extends SvgLoader<ByteData> {
  /// Creates an instance of [SvgAssetLoader] for loading SVG assets.
  ///
  /// The [assetName] represents the name of the asset to load, e.g., 'foo.svg'.
  /// The optional [packageName] indicates the package containing the asset.
  /// The optional [assetBundle] specifies the asset bundle to use;
  /// if null, [DefaultAssetBundle] will be used.
  const SvgAssetLoader(
    this.assetName, {
    this.packageName,
    this.assetBundle,
    super.theme,
    super.colorMapper,
  });

  /// The name of the asset to load, e.g., 'foo.svg'.
  final String assetName;

  /// The optional package containing the asset.
  final String? packageName;

  /// The optional asset bundle to use; defaults to [DefaultAssetBundle] if null.
  final AssetBundle? assetBundle;

  /// Resolves the appropriate asset bundle to use for loading assets.
  AssetBundle _resolveBundle(BuildContext? context) {
    if (assetBundle != null) {
      return assetBundle!;
    }
    if (context != null) {
      return DefaultAssetBundle.of(context);
    }
    return rootBundle;
  }

  /// Prepares the message to be used for loading the SVG asset.
  /// Returns the [ByteData] of the loaded asset.
  @override
  Future<ByteData?> prepareMessage(BuildContext? context) async {
    try {
      return await _resolveBundle(context).load(
        packageName == null ? assetName : 'packages/$packageName/$assetName',
      );
    } catch (e) {
      // Handle loading error, log it, or rethrow it
      print('Error loading asset: $e');
      return null;
    }
  }

  /// Provides the SVG string from the loaded [ByteData].
  @override
  String provideSvg(ByteData? message) {
    if (message == null) {
      return ''; // Return an empty string if message is null
    }
    return utf8.decode(message.buffer.asUint8List(), allowMalformed: true);
  }

  /// Creates a cache key for the SVG loader.
  @override
  SvgCacheKey cacheKey(BuildContext? context) {
    final SvgTheme theme = getTheme(context);
    return SvgCacheKey(
      theme: theme,
      colorMapper: colorMapper,
      keyData: _AssetByteLoaderCacheKey(
        assetName,
        packageName,
        _resolveBundle(context),
      ),
    );
  }

  @override
  int get hashCode =>
      Object.hash(assetName, packageName, assetBundle, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgAssetLoader &&
        other.assetName == assetName &&
        other.packageName == packageName &&
        other.assetBundle == assetBundle &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() =>
      'SvgAssetLoader(assetName: $assetName, packageName: $packageName)';
}

class SvgNetworkLoader extends SvgLoader<Uint8List> {
  /// Creates an instance of [SvgNetworkLoader] for loading SVGs from a network.
  ///
  /// The [url] parameter is the Uri-encoded resource address of the SVG.
  /// Optional [headers] can be provided for the HTTP request.
  /// An optional [httpClient] can be supplied for custom HTTP operations.
  const SvgNetworkLoader(
    this.url, {
    this.headers,
    super.theme,
    super.colorMapper,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// The Uri-encoded resource address for the SVG.
  final String url;

  /// Optional HTTP headers to send with the request.
  final Map<String, String>? headers;

  /// The optional HTTP client to use for network requests.
  final http.Client? _httpClient;

  /// Prepares the message by fetching the SVG data from the network.
  @override
  Future<Uint8List?> prepareMessage(BuildContext? context) async {
    final http.Client client = _httpClient ?? http.Client();
    try {
      final response = await client.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        // Handle non-200 responses appropriately
        print('Failed to load SVG from $url: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle network errors, log them
      print('Error loading SVG from $url: $e');
      return null;
    } finally {
      if (_httpClient == null) {
        client.close(); // Close the client only if it was created internally
      }
    }
  }

  /// Provides the SVG string from the loaded [Uint8List].
  @override
  String provideSvg(Uint8List? message) {
    if (message == null) {
      return ''; // Return an empty string if message is null
    }
    return utf8.decode(message, allowMalformed: true);
  }

  @override
  int get hashCode => Object.hash(url, headers, theme, colorMapper);

  @override
  bool operator ==(Object other) {
    return other is SvgNetworkLoader &&
        other.url == url &&
        other.headers == headers &&
        other.theme == theme &&
        other.colorMapper == colorMapper;
  }

  @override
  String toString() => 'SvgNetworkLoader(url: $url)';
}
