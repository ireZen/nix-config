{pkgs, ...}: let
  unity-editor = pkgs.writeShellScriptBin "unity-editor" ''
    exec ${pkgs.unityhub.fhsEnv}/bin/unityhub-fhs-env \
      "$HOME/Unity/Hub/Editor/''${UNITY_VERSION:-6000.6.4f1}/Editor/Unity" "$@"
  '';
  androidSdk = (pkgs.androidenv.composeAndroidPackages {
    platformVersions = ["35"];
    buildToolsVersions = ["35.0.0"];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = ["google_apis_playstore"];
    abiVersions = ["x86_64"];
    includeNDK = false;   # Unity brings its own NDK
  }).androidsdk;
in {
  home.packages = with pkgs; [
    unityhub
    unity-editor          # Hub + Editor FHS wrapper (unfree — your allowUnfreePredicate already covers it)
    androidSdk
  ];
  home.sessionVariables = {
    UNITY_EDITOR = "${unity-editor}/bin/unity-editor";
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  };
}