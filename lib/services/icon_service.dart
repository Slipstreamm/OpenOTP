import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'logger_service.dart';

class IconService {
  final LoggerService _logger = LoggerService();

  // Cache for icons to avoid repeated file system checks
  final Map<String, String?> _iconCache = {};

  // Find the icon path for a given issuer or name
  String? findIconPath(String issuer, String name) {
    _logger.d('Finding icon for issuer: $issuer, name: $name');

    // Check cache first
    final cacheKey = '$issuer:$name';
    if (_iconCache.containsKey(cacheKey)) {
      _logger.d('Using cached icon path for $cacheKey: ${_iconCache[cacheKey]}');
      return _iconCache[cacheKey];
    }

    String? iconPath;

    // Try to find icon based on issuer first
    if (issuer.isNotEmpty) {
      iconPath = _findIconForDomain(issuer);
      if (iconPath != null) {
        _iconCache[cacheKey] = iconPath;
        return iconPath;
      }
    }

    // If no icon found for issuer, try with name
    iconPath = _findIconForDomain(name);

    // Cache the result (even if null)
    _iconCache[cacheKey] = iconPath;
    return iconPath;
  }

  // Common domain TLDs to check when a user enters just the base name
  final List<String> _commonTlds = ['com', 'org', 'net', 'io', 'app', 'dev'];

  // Find icon for a domain or app name
  String? _findIconForDomain(String domain) {
    _logger.d('Looking for icon for domain/name: $domain');

    // Strip protocol if present
    domain = domain.replaceAll(RegExp(r'^https?://'), '');

    // Extract domain without TLD
    final domainParts = domain.split('.');
    String baseDomain = domain;

    // If it has multiple parts (like github.com), use the domain structure
    if (domainParts.length > 1) {
      // Try with full domain first (e.g., github.com)
      String fullDomainPath = 'assets/vectors/$domain';

      // Extract base domain (e.g., github from github.com)
      baseDomain = domainParts[domainParts.length - 2];

      // Check for domain/basedomain-icon.svg (e.g., github.com/github-icon.svg)
      String fullDomainIconAltPath = '$fullDomainPath/$baseDomain-icon.svg';
      if (_fileExists(fullDomainIconAltPath)) {
        _logger.d('Found icon at $fullDomainIconAltPath');
        return fullDomainIconAltPath;
      }

      // Check for domain/basedomain.svg (e.g., github.com/github.svg)
      String fullDomainIconPath = '$fullDomainPath/$baseDomain.svg';
      if (_fileExists(fullDomainIconPath)) {
        _logger.d('Found icon at $fullDomainIconPath');
        return fullDomainIconPath;
      }
    } else {
      // For single-word inputs (like 'github'), try common domain patterns
      _logger.d('Single word input, trying common domain patterns for: $domain');

      // Try common TLDs (e.g., github.com, github.org, etc.)
      for (final tld in _commonTlds) {
        final domainWithTld = '$domain.$tld';
        final domainPath = 'assets/vectors/$domainWithTld';

        // Check for domainWithTld/domain.svg (e.g., github.com/github.svg)
        String domainIconPath = '$domainPath/$domain.svg';
        if (_fileExists(domainIconPath)) {
          _logger.d('Found icon at $domainIconPath using common TLD pattern');
          return domainIconPath;
        }

        // Check for domainWithTld/domain-icon.svg (e.g., github.com/github-icon.svg)
        String domainIconAltPath = '$domainPath/$domain-icon.svg';
        if (_fileExists(domainIconAltPath)) {
          _logger.d('Found icon at $domainIconAltPath using common TLD pattern');
          return domainIconAltPath;
        }
      }
    }

    // Try with just the base name (for non-domain entries or fallback)

    // Check for basedomain.svg directly in vectors folder
    String directIconPath = 'assets/vectors/$baseDomain.svg';
    if (_fileExists(directIconPath)) {
      _logger.d('Found icon at $directIconPath');
      return directIconPath;
    }

    // Check for basedomain-icon.svg directly in vectors folder
    String directIconAltPath = 'assets/vectors/$baseDomain-icon.svg';
    if (_fileExists(directIconAltPath)) {
      _logger.d('Found icon at $directIconAltPath');
      return directIconAltPath;
    }

    // Check for basedomain/basedomain-icon.svg
    String baseFolderIconAltPath = 'assets/vectors/$baseDomain/$baseDomain-icon.svg';
    if (_fileExists(baseFolderIconAltPath)) {
      _logger.d('Found icon at $baseFolderIconAltPath');
      return baseFolderIconAltPath;
    }

    // Check for basedomain/basedomain.svg
    String baseFolderIconPath = 'assets/vectors/$baseDomain/$baseDomain.svg';
    if (_fileExists(baseFolderIconPath)) {
      _logger.d('Found icon at $baseFolderIconPath');
      return baseFolderIconPath;
    }

    _logger.d('No icon found for $domain');
    return null;
  }

  // In Flutter, we can't reliably check if an asset exists at runtime
  // So we'll just assume it exists and let the SVG loading handle any missing files
  // This is a limitation of Flutter's asset system
  bool _fileExists(String assetPath) {
    // For debugging purposes, log the path we're checking
    _logger.d('Checking for asset: $assetPath');

    // We'll return true and let the SVG loading handle any missing files
    // This is a workaround for Flutter's asset system limitations
    return true;
  }

  // Get an SVG widget for the given issuer and name
  Widget? getIconWidget(String issuer, String name, {double size = 24.0, Color? color}) {
    final iconPath = findIconPath(issuer, name);
    if (iconPath != null) {
      _logger.d('Attempting to load SVG icon: $iconPath');
      try {
        // Use SvgPicture.asset with a placeholder builder to handle errors
        return SvgPicture.asset(
          iconPath,
          width: size,
          height: size,
          colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
          placeholderBuilder: (BuildContext context) {
            _logger.w('SVG failed to load, using fallback: $iconPath');
            return _buildFallbackIcon(issuer, name, size: size, theme: Theme.of(context));
          },
        );
      } catch (e, stackTrace) {
        _logger.e('Error loading SVG icon: $iconPath', e, stackTrace);
        return _buildFallbackIcon(issuer, name, size: size, theme: null);
      }
    }
    return _buildFallbackIcon(issuer, name, size: size, theme: null);
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
