{ pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "056024b4471707d5472f83fc5121e57ce3dce179";
    hash = "sha256-rJDNBie8kQR3JEwIUbdbyLvlg7RvqDVpBLb0290Rn6M=";
    sparseCheckout = [ "skills/agent-browser" ];
  };
in
{
  agent-browser = "${src}/skills/agent-browser";
}
