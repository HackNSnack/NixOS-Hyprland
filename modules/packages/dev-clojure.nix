# Clojure development environment
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    clojure
    clojure-lsp
    leiningen
    babashka
    jdk21_headless
    cljfmt      # Clojure formatter
  ];
}
