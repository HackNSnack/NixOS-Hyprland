# Cloud platform tools
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Azure
    (azure-cli.withExtensions [
      azure-cli.extensions.aks-preview
      azure-cli.extensions.webapp
      azure-cli.extensions.redisenterprise
    ])
    azuredatastudio  # Azure SQL GUI tool

    # Google Cloud
    google-cloud-sdk
  ];
}
