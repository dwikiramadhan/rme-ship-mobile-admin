import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'dio_client.dart';

/// Service to automatically discover the RME backend server running on the local
/// Wi-Fi/LAN subnet without requiring manual IP configuration from the user.
class ServerDiscovery {
  ServerDiscovery._();

  static const List<int> defaultCandidatePorts = [8080];

  /// Discovers the backend server on the current LAN/Wi-Fi subnet.
  /// Checks candidate IPs on [ports] (default 8080).
  /// If found, saves and applies the new base URL automatically.
  static Future<String?> autoDiscover({
    List<int> ports = defaultCandidatePorts,
    void Function(String progressMessage)? onProgress,
  }) async {
    // 1. Fast check: is the current configured baseUrl already active?
    final currentUrl = ApiConfig.baseUrl;
    if (await ApiConfig.testConnection(currentUrl)) {
      debugPrint('⚡ [Discovery] Current baseUrl $currentUrl is active');
      return currentUrl;
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final localIps = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('169.254') &&
              !addr.address.startsWith('127.')) {
            localIps.add(addr.address);
          }
        }
      }

      if (localIps.isEmpty) {
        debugPrint('⚠️ [Discovery] No local IPv4 network interface found');
        return null;
      }

      for (final localIp in localIps) {
        final prefix = localIp.substring(0, localIp.lastIndexOf('.') + 1);
        final myHostNum =
            int.tryParse(localIp.substring(localIp.lastIndexOf('.') + 1)) ?? 0;

        for (final port in ports) {
          onProgress?.call('Mencari server di subnet $prefix*:$port...');

          // High priority candidates: gateway (.1), host itself (if local dev), common static servers (.100, .200, .10, .2)
          final priorityList = <String>[
            '${prefix}1',
            if (myHostNum > 0) localIp,
            '${prefix}100',
            '${prefix}2',
            '${prefix}10',
            '${prefix}200',
          ];

          // Check priority list first
          for (final ip in priorityList) {
            final targetUrl = 'http://$ip:$port';
            if (await _pingHealth(targetUrl)) {
              await _applyFoundUrl(targetUrl);
              return targetUrl;
            }
          }

          // Full subnet scan in batches
          final remainingIps = <String>[];
          for (var i = 1; i <= 254; i++) {
            final ip = '$prefix$i';
            if (!priorityList.contains(ip)) {
              remainingIps.add(ip);
            }
          }

          // Process in batches of 40
          for (var i = 0; i < remainingIps.length; i += 40) {
            final end = (i + 40 > remainingIps.length)
                ? remainingIps.length
                : i + 40;
            final batch = remainingIps.sublist(i, end);

            final socketResults = await Future.wait(
              batch.map((ip) => _testSocket(ip, port, timeoutMs: 350)),
            );

            for (final liveIp in socketResults) {
              if (liveIp != null) {
                final targetUrl = 'http://$liveIp:$port';
                if (await _pingHealth(targetUrl)) {
                  await _applyFoundUrl(targetUrl);
                  return targetUrl;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Discovery] Auto-discovery error: $e');
    }

    return null;
  }

  static Future<String?> _testSocket(
    String ip,
    int port, {
    int timeoutMs = 350,
  }) async {
    try {
      final s = await Socket.connect(
        ip,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      s.destroy();
      return ip;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _pingHealth(String targetUrl) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 700),
          receiveTimeout: const Duration(milliseconds: 700),
        ),
      );
      final res = await dio.get('$targetUrl${ApiConfig.healthPath}');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _applyFoundUrl(String targetUrl) async {
    debugPrint('🎯 [Discovery] Found RME Backend server at $targetUrl');
    await ApiConfig.saveCustomBaseUrl(targetUrl);
    DioClient.instance.options.baseUrl = ApiConfig.baseUrl;
  }
}
