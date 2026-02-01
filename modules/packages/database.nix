# Database tools
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    mysql84
    redis
    redisinsight
  ];
}
