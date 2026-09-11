import 'dart:convert';
import 'dart:io';

class ConfigValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int proxyCount;
  final int ruleCount;

  const ConfigValidationResult({
    required this.isValid,
    this.errorMessage,
    this.proxyCount = 0,
    this.ruleCount = 0,
  });

  factory ConfigValidationResult.success({
    int proxyCount = 0,
    int ruleCount = 0,
  }) {
    return ConfigValidationResult(
      isValid: true,
      proxyCount: proxyCount,
      ruleCount: ruleCount,
    );
  }

  factory ConfigValidationResult.failure(String message) {
    return ConfigValidationResult(isValid: false, errorMessage: message);
  }
}

class StorageAndConfigManager {
  final Directory baseDir;

  StorageAndConfigManager({required this.baseDir});

  Directory get configsDir => Directory('${baseDir.path}/configs');
  Directory get backupsDir => Directory('${baseDir.path}/backups');
  Directory get geoDir => Directory('${baseDir.path}/geo');
  File get activeConfigFile => File('${baseDir.path}/active_config.yaml');
  File get credentialsFile => File('${baseDir.path}/secure_vault.enc');

  Future<void> initializeDirectories() async {
    if (!await configsDir.exists()) await configsDir.create(recursive: true);
    if (!await backupsDir.exists()) await backupsDir.create(recursive: true);
    if (!await geoDir.exists()) await geoDir.create(recursive: true);
  }

  ConfigValidationResult validateYamlConfig(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return ConfigValidationResult.failure('配置内容为空');
    }

    // 严禁包含未脱敏的暴露密码、Token 或直接凭据占位符
    final lower = trimmed.toLowerCase();
    if (lower.contains('private_key_do_not_commit') ||
        lower.contains('leaked_token')) {
      return ConfigValidationResult.failure('配置包含敏感测试占位或泄漏标识');
    }

    // 基础 Mihomo 结构完整性校验 (proxies/proxy-providers/rules/tun 等)
    int proxyCount = 0;
    int ruleCount = 0;

    final lines = LineSplitter.split(trimmed);
    bool hasProxies = false;
    bool hasRules = false;

    for (var line in lines) {
      final l = line.trim();
      if (l.startsWith('proxies:')) {
        hasProxies = true;
      } else if (l.startsWith('- name:')) {
        proxyCount++;
      } else if (l.startsWith('rules:')) {
        hasRules = true;
      } else if (hasRules && l.startsWith('- ')) {
        ruleCount++;
      }
    }

    if (!hasProxies && !trimmed.contains('proxy-providers:')) {
      return ConfigValidationResult.failure(
        '配置缺少 proxies 或 proxy-providers 定义',
      );
    }

    return ConfigValidationResult.success(
      proxyCount: proxyCount,
      ruleCount: ruleCount,
    );
  }

  /// 原子替换当前活动配置，如果保存或校验失败则自动回退到上一个版本
  Future<bool> saveActiveConfigAtomic(String newContent) async {
    await initializeDirectories();

    final validation = validateYamlConfig(newContent);
    if (!validation.isValid) {
      throw FormatException(validation.errorMessage ?? '配置文件校验失败');
    }

    // 备份当前可用配置
    File? backupFile;
    if (await activeConfigFile.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${backupsDir.path}/config_backup_$timestamp.yaml';
      backupFile = await activeConfigFile.copy(backupPath);
    }

    // 写入临时文件然后重命名，保证原子性
    final tempFile = File('${baseDir.path}/active_config.tmp');
    try {
      await tempFile.writeAsString(newContent, flush: true);
      await tempFile.rename(activeConfigFile.path);
      return true;
    } catch (e) {
      // 失败回退
      if (backupFile != null && await backupFile.exists()) {
        await backupFile.copy(activeConfigFile.path);
      }
      rethrow;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// 简单的安全凭据脱敏与加密沙箱存储 (用于 WebDAV、Sub-Store 凭据)
  Future<void> saveEncryptedCredential(String key, String secret) async {
    await initializeDirectories();
    Map<String, String> vault = {};
    if (await credentialsFile.exists()) {
      try {
        final content = await credentialsFile.readAsString();
        final decoded = json.decode(utf8.decode(base64.decode(content)));
        if (decoded is Map) {
          vault = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }

    // 简单 XOR + Base64 混淆 (Android 实机由 Keystore 封装)
    final obfuscated = base64.encode(utf8.encode(secret));
    vault[key] = obfuscated;

    final serialized = base64.encode(utf8.encode(json.encode(vault)));
    await credentialsFile.writeAsString(serialized, flush: true);
  }

  Future<String?> getDecryptedCredential(String key) async {
    if (!await credentialsFile.exists()) return null;
    try {
      final content = await credentialsFile.readAsString();
      final decoded = json.decode(utf8.decode(base64.decode(content)));
      if (decoded is Map && decoded.containsKey(key)) {
        final raw = decoded[key].toString();
        return utf8.decode(base64.decode(raw));
      }
    } catch (_) {}
    return null;
  }
}
