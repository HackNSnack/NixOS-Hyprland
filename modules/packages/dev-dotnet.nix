# .NET development environment
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # .NET SDK and runtime
    (
      with dotnetCorePackages;
      combinePackages [
        dotnet_9.sdk
        dotnet_9.runtime
        dotnet_9.aspnetcore
      ]
    )

    # C# tooling
    csharp-ls   # Language server
    csharpier   # Formatter
    netcoredbg  # Debugger
  ];
}
