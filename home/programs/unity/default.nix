{pkgs, ...}: let
  unity-editor = pkgs.writeShellScriptBin "unity-editor" ''
    exec ${pkgs.unityhub.fhsEnv}/bin/unityhub-fhs-env \
      "$HOME/Unity/Hub/Editor/''${UNITY_VERSION:-6000.6.4f1}/Editor/Unity" "$@"
  '';
in {
  home.packages = with pkgs; [
    unityhub          # Hub + Editor FHS wrapper (unfree — your allowUnfreePredicate already covers it)
  ];
  home.sessionVariables.UNITY_EDITOR = "${unity-editor}/bin/unity-editor";
}