class WindowsChannelConfig {
  static const bool isBeta = bool.fromEnvironment('APP_BETA', defaultValue: false);

  static String get appName => isBeta ? 'BfClash Beta' : 'BfClash';
  static String get appId => isBeta
      ? 'A19F870C-739B-4FA0-A39B-67E082DEBF01'
      : '728B3532-C74B-4870-9068-BE70FE12A3E6';
  static String get executableName => isBeta ? 'BfClash-Beta.exe' : 'BfClash.exe';
  static String get helperServiceName => isBeta ? 'BfClashHelperServiceBeta' : 'BfClashHelperService';
  static String get singleInstanceMutex => isBeta
      ? 'Global\\BfClashBeta_SingleInstance'
      : 'Global\\BfClash_SingleInstance';
  static String get dataDirectoryName => isBeta ? 'com.bfclash.client.beta' : 'com.bfclash.client';
  static String get pipePrefix => isBeta ? r'\\.\pipe\BfClashCoreBeta_' : r'\\.\pipe\BfClashCore_';

  static String get updateChannel => isBeta ? 'beta' : 'stable';
}
