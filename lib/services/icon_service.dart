import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Keep this for rootBundle
import 'package:flutter_svg/flutter_svg.dart';
import 'logger_service.dart';

class IconService {
  final LoggerService _logger = LoggerService();

  // Cache for icons to avoid repeated file system checks
  final Map<String, String?> _iconCache = {};

  // Find the icon path for a given issuer or name
  Future<String?> findIconPath(String issuer, String name) async {
    // Convert to lowercase for case-insensitive matching
    final lowerIssuer = issuer.toLowerCase();
    final lowerName = name.toLowerCase();

    _logger.d('Finding icon for issuer: $issuer, name: $name');

    // Check cache first
    final cacheKey = '$lowerIssuer:$lowerName';
    if (_iconCache.containsKey(cacheKey)) {
      _logger.d('Using cached icon path for $cacheKey: ${_iconCache[cacheKey]}');
      return _iconCache[cacheKey];
    }

    String? iconPath;

    // Try to find icon based on issuer first
    if (lowerIssuer.isNotEmpty) {
      iconPath = await _findIconForDomain(lowerIssuer);
      if (iconPath != null) {
        _iconCache[cacheKey] = iconPath;
        return iconPath;
      }
    }

    // If no icon found for issuer, try with name
    iconPath = await _findIconForDomain(lowerName);

    // Cache the result (even if null)
    _iconCache[cacheKey] = iconPath;
    return iconPath;
  }

  // Common domain TLDs to check when a user enters just the base name
  // Note: These are without the leading dot to prevent double-dot issues
  final List<String> _commonTlds = [
    'com',
    'org',
    'net',
    'int',
    'edu',
    'gov',
    'mil',
    'co',
    'io',
    'ai',
    'app',
    'dev',
    'tech',
    'xyz',
    'me',
    'info',
    'biz',
    'online',
    'site',
    'store',
    'blog',
    'us',
    'uk',
    'ca',
    'de',
    'jp',
    'fr',
    'au',
    'in',
    'cn',
    'br',
    'ru',
    'ch',
    'nl',
    'se',
    'es',
    'it',
    'pl',
    'ir',
    'za',
    'mx',
    'kr',
    'tr',
    'ar',
    'sg',
    'id',
    'hk',
    'tv',
    'fm',
    'ly',
    'to',
    'ws',
    'cc',
    'mobi',
    'name',
    'pro',
    'jobs',
    'tel',
    'asia',
    'travel',
    'museum',
    'cat',
    'coop',
    'aero',
    'int',
    'bank',
    'insurance',
    'law',
    'health',
    'finance',
    'credit',
    'cloud',
    'design',
    'agency',
    'studio',
    'media',
    'news',
    'press',
    'today',
    'email',
    'group',
    'company',
    'team',
    'network',
    'support',
    'systems',
    'solutions',
    'capital',
    'ventures',
    'life',
    'world',
    'zone',
    'space',
    'tools',
    'cool',
    'ninja',
    'expert',
    'love',
    'fun',
    'party',
    'vip',
    'games',
    'social',
    'photo',
    'pics',
    'camera',
    'gallery',
    'art',
    'music',
    'film',
    'theatre',
    'dance',
    'bar',
    'cafe',
    'restaurant',
    'pizza',
    'beer',
    'fashion',
    'style',
    'beauty',
    'makeup',
    'build',
    'construction',
    'contractors',
    'engineering',
    'software',
    'digital',
    'computer',
    'technology',
    'academy',
    'school',
    'college',
    'university',
    'education',
    'church',
    'bible',
    'faith',
    'christmas',
    'loc', // For local domains
  ];

  // Find icon for a domain or app name
  Future<String?> _findIconForDomain(String domain) async {
    _logger.d('Looking for icon for domain/name: $domain');

    // Domain should already be lowercase from the calling method
    // Strip protocol if present
    domain = domain.replaceAll(RegExp(r'^https?://'), '');

    // Clean up the domain - remove any trailing dots to prevent double dots
    domain = domain.replaceAll(RegExp(r'\.$'), '');

    // Remove any consecutive dots (e.g., 'admin..com' -> 'admin.com')
    domain = domain.replaceAll(RegExp(r'\.{2,}'), '.');

    // Extract domain parts
    final domainParts = domain.split('.');
    String baseDomain = domain;
    String? subdomain;

    // If it has multiple parts, extract the base domain and subdomain if present
    if (domainParts.length > 1) {
      // Try with full domain first (e.g., github.com)
      String fullDomainPath = 'assets/vectors/$domain';

      // Extract base domain (e.g., github from github.com)
      baseDomain = domainParts[domainParts.length - 2];
      _logger.d('Extracted base domain: $baseDomain from $domain');

      // Check for subdomain (e.g., aws.amazon.com -> aws is subdomain, amazon is base domain)
      if (domainParts.length > 2) {
        subdomain = domainParts[domainParts.length - 3];
        _logger.d('Extracted subdomain: $subdomain from $domain');
      }

      // Check for full domain path icons first

      // Check for domain/basedomain-icon.svg (e.g., github.com/github-icon.svg)
      String fullDomainIconAltPath = '$fullDomainPath/$baseDomain-icon.svg';
      if (await _checkAssetExists(fullDomainIconAltPath)) {
        _logger.d('Found icon at $fullDomainIconAltPath');
        return fullDomainIconAltPath;
      }

      // Check for domain/basedomain.svg (e.g., github.com/github.svg)
      String fullDomainIconPath = '$fullDomainPath/$baseDomain.svg';
      if (await _checkAssetExists(fullDomainIconPath)) {
        _logger.d('Found icon at $fullDomainIconPath');
        return fullDomainIconPath;
      }

      // If we have a subdomain, check for subdomain-specific icons
      if (subdomain != null) {
        // Check for domain/subdomain.svg (e.g., aws.amazon.com/aws.svg)
        String subdomainIconPath = '$fullDomainPath/$subdomain.svg';
        if (await _checkAssetExists(subdomainIconPath)) {
          _logger.d('Found subdomain icon at $subdomainIconPath');
          return subdomainIconPath;
        }

        // Check for domain/subdomain-icon.svg (e.g., aws.amazon.com/aws-icon.svg)
        String subdomainIconAltPath = '$fullDomainPath/$subdomain-icon.svg';
        if (await _checkAssetExists(subdomainIconAltPath)) {
          _logger.d('Found subdomain icon at $subdomainIconAltPath');
          return subdomainIconAltPath;
        }
      }
    } else {
      // For single-word inputs (like 'github'), try common domain patterns
      _logger.d('Single word input, trying common domain patterns for: $domain');

      // Try common TLDs (e.g., github.com, github.org, etc.)
      for (final tld in _commonTlds) {
        final domainWithTld = '$domain.$tld';
        final domainPath = 'assets/vectors/$domainWithTld';

        // Check for domainWithTld/domain-icon.svg (e.g., github.com/github-icon.svg)
        String domainIconAltPath = '$domainPath/$domain-icon.svg';
        if (await _checkAssetExists(domainIconAltPath)) {
          _logger.d('Found icon at $domainIconAltPath using common TLD pattern');
          return domainIconAltPath;
        }

        // Check for domainWithTld/domain.svg (e.g., github.com/github.svg)
        String domainIconPath = '$domainPath/$domain.svg';
        if (await _checkAssetExists(domainIconPath)) {
          _logger.d('Found icon at $domainIconPath using common TLD pattern');
          return domainIconPath;
        }
      }
    }

    // Try with just the base name (for non-domain entries or fallback)

    // Check for basedomain-icon.svg directly in vectors folder
    String directIconAltPath = 'assets/vectors/$baseDomain-icon.svg';
    if (await _checkAssetExists(directIconAltPath)) {
      _logger.d('Found icon at $directIconAltPath');
      return directIconAltPath;
    }

    // Check for basedomain.svg directly in vectors folder
    String directIconPath = 'assets/vectors/$baseDomain.svg';
    if (await _checkAssetExists(directIconPath)) {
      _logger.d('Found icon at $directIconPath');
      return directIconPath;
    }

    // Check for basedomain/basedomain-icon.svg
    String baseFolderIconAltPath = 'assets/vectors/$baseDomain/$baseDomain-icon.svg';
    if (await _checkAssetExists(baseFolderIconAltPath)) {
      _logger.d('Found icon at $baseFolderIconAltPath');
      return baseFolderIconAltPath;
    }

    // Check for basedomain/basedomain.svg
    String baseFolderIconPath = 'assets/vectors/$baseDomain/$baseDomain.svg';
    if (await _checkAssetExists(baseFolderIconPath)) {
      _logger.d('Found icon at $baseFolderIconPath');
      return baseFolderIconPath;
    }

    // If we have a subdomain, check for combined naming patterns in the base domain folder
    if (subdomain != null) {
      // Check for basedomain/basedomain-subdomain.svg (e.g., amazon/amazon-aws.svg)
      String baseSubdomainPath = 'assets/vectors/$baseDomain/$baseDomain-$subdomain.svg';
      if (await _checkAssetExists(baseSubdomainPath)) {
        _logger.d('Found base-subdomain icon at $baseSubdomainPath');
        return baseSubdomainPath;
      }

      // Check for basedomain/subdomain-basedomain.svg (e.g., amazon/aws-amazon.svg)
      String subdomainBasePath = 'assets/vectors/$baseDomain/$subdomain-$baseDomain.svg';
      if (await _checkAssetExists(subdomainBasePath)) {
        _logger.d('Found subdomain-base icon at $subdomainBasePath');
        return subdomainBasePath;
      }

      // Check for basedomain/subdomain.svg (e.g., amazon/aws.svg)
      String subdomainInBasePath = 'assets/vectors/$baseDomain/$subdomain.svg';
      if (await _checkAssetExists(subdomainInBasePath)) {
        _logger.d('Found subdomain in base folder at $subdomainInBasePath');
        return subdomainInBasePath;
      }

      // Check directly in vectors folder for combined names
      String combinedPath1 = 'assets/vectors/$baseDomain-$subdomain.svg';
      if (await _checkAssetExists(combinedPath1)) {
        _logger.d('Found combined icon at $combinedPath1');
        return combinedPath1;
      }

      String combinedPath2 = 'assets/vectors/$subdomain-$baseDomain.svg';
      if (await _checkAssetExists(combinedPath2)) {
        _logger.d('Found combined icon at $combinedPath2');
        return combinedPath2;
      }
    }

    _logger.d('No icon found for $domain');
    return null;
  }

  // Cache for asset existence checks to avoid repeated checks
  final Map<String, bool> _assetExistsCache = {};

  // Check if an asset exists using a more reliable method that works across all platforms
  Future<bool> _checkAssetExists(String assetPath) async {
    // Check cache first for better performance
    if (_assetExistsCache.containsKey(assetPath)) {
      return _assetExistsCache[assetPath]!;
    }

    _logger.d('Checking if asset exists: $assetPath');
    try {
      // First approach: Use the preloaded asset manifest if available
      if (_assetManifestCache != null) {
        final exists = _assetManifestCache!.containsKey(assetPath);
        if (exists) {
          _logger.d('Asset found in preloaded manifest: $assetPath');
          _assetExistsCache[assetPath] = true;
          return true;
        }
      } else {
        // If manifest not preloaded, try to load it now
        try {
          await _preloadAssetManifest();
          if (_assetManifestCache != null && _assetManifestCache!.containsKey(assetPath)) {
            _logger.d('Asset found in just-loaded manifest: $assetPath');
            _assetExistsCache[assetPath] = true;
            return true;
          }
        } catch (manifestError) {
          _logger.w('Error loading manifest for asset check: $assetPath', manifestError);
          // Continue to the next approach if manifest check fails
        }
      }

      // Second approach: Try to load the asset directly
      // This is a fallback in case the manifest approach doesn't work
      try {
        await rootBundle.load(assetPath);
        _logger.d('Asset exists (direct load): $assetPath');
        _assetExistsCache[assetPath] = true;
        return true;
      } catch (loadError) {
        _logger.d('Asset does not exist (direct load): $assetPath');
        _assetExistsCache[assetPath] = false;
        return false;
      }
    } catch (e) {
      // If we get an error during any check, log it and return false
      _logger.e('Error checking if asset exists: $assetPath', e);
      _assetExistsCache[assetPath] = false;
      return false;
    }
  }

  // Load SVG data directly from the asset bundle
  Future<String?> _loadSvgStringFromAsset(String assetPath) async {
    _logger.d('Loading SVG string from asset: $assetPath');
    try {
      // Check if the asset exists in the manifest
      bool exists = await _checkAssetExists(assetPath);
      if (!exists) {
        _logger.w('Asset not found in manifest: $assetPath');
        return null;
      }

      // Load the SVG file as a string
      final String svgString = await rootBundle.loadString(assetPath);
      return svgString;
    } catch (e, stackTrace) {
      _logger.e('Error loading SVG string from asset: $assetPath', e, stackTrace);
      return null;
    }
  }

  // Safely load an SVG asset with proper error handling
  Widget _safeLoadSvgAsset(String assetPath, {double size = 24.0, Color? color, required Widget fallbackWidget}) {
    _logger.d('Safely loading SVG asset: $assetPath');

    // Use a FutureBuilder to handle the asynchronous loading of the SVG asset
    return FutureBuilder<String?>(
      future: _loadSvgStringFromAsset(assetPath),
      builder: (context, snapshot) {
        // If we successfully loaded the SVG string
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          try {
            // Create SVG from the string data
            return SvgPicture.string(snapshot.data!, width: size, height: size, colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null);
          } catch (e, stackTrace) {
            // If parsing the SVG fails, log and return fallback
            _logger.e('Error parsing SVG string: $assetPath', e, stackTrace);
            return fallbackWidget;
          }
        }
        // If there was an error or no data, return the fallback widget
        else if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            _logger.e('Error loading SVG: $assetPath', snapshot.error, snapshot.stackTrace);
          } else {
            _logger.w('No SVG data loaded for: $assetPath');
          }
          return fallbackWidget;
        }
        // While loading, show the fallback widget
        else {
          return fallbackWidget;
        }
      },
    );
  }

  // Get an SVG widget for the given issuer and name
  Widget getIconWidget(String issuer, String name, {double size = 24.0, Color? color}) {
    // Use a FutureBuilder to handle the async path lookup
    return FutureBuilder<String?>(
      // Find the icon path asynchronously
      future: findIconPath(issuer, name),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        // Create the fallback widget
        final fallbackWidget = _buildFallbackIcon(issuer, name, size: size, theme: Theme.of(context));

        // If we have a valid path, try to load the SVG
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          final iconPath = snapshot.data!;
          _logger.d('Attempting to load SVG icon: $iconPath');

          // Use the safe loading method which uses rootBundle internally
          return _safeLoadSvgAsset(iconPath, size: size, color: color, fallbackWidget: fallbackWidget);
        }

        // If we're still loading or there was an error, use the fallback
        return fallbackWidget;
      },
    );
  }

  // Cache for the asset manifest
  Map<String, dynamic>? _assetManifestCache;

  // Preload the asset manifest to make subsequent asset checks faster
  Future<void> _preloadAssetManifest() async {
    if (_assetManifestCache != null) return; // Already loaded

    try {
      _logger.d('Preloading asset manifest');
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      _assetManifestCache = json.decode(manifestContent);
      _logger.i('Asset manifest preloaded with ${_assetManifestCache!.length} entries');
    } catch (e, stackTrace) {
      _logger.w('Error preloading asset manifest', e, stackTrace);
      // Don't throw - we'll fall back to direct loading if needed
    }
  }

  // Preload common icons to improve performance
  Future<void> preloadCommonIcons() async {
    _logger.d('Preloading common icons');
    try {
      // First preload the asset manifest
      await _preloadAssetManifest();

      // List of common services that might be used frequently
      final commonServices = [
        'google.com',
        'github.com',
        'microsoft.com',
        'apple.com',
        'amazon.com',
        'facebook.com',
        'twitter.com',
        'instagram.com',
        'linkedin.com',
        'dropbox.com',
        'slack.com',
        'discord.com',
        'zoom.us',
        'paypal.com',
        'netflix.com',
        'spotify.com',
        'steam',
        'reddit.com',
      ];

      // Preload icons for common services
      for (final service in commonServices) {
        await findIconPath(service, service);
      }
      _logger.i('Preloaded common icons');
    } catch (e, stackTrace) {
      // Log but don't throw - preloading is optional
      _logger.w('Error preloading common icons', e, stackTrace);
    }
  }

  // Build a fallback icon with the first letter of the name or issuer
  Widget _buildFallbackIcon(String issuer, String name, {double size = 24.0, ThemeData? theme}) {
    final String firstLetter = (issuer.isNotEmpty ? issuer : name).substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme?.primaryColor ?? Colors.grey, // Use a standard color for fallback
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Center(child: Text(firstLetter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.5))),
    );
  }
}
