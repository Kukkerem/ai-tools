{ inputs }:

let
  src = inputs.caveman;
in
{
  caveman = "${src}/skills/caveman";
  caveman-commit = "${src}/skills/caveman-commit";
  caveman-review = "${src}/skills/caveman-review";
  caveman-help = "${src}/skills/caveman-help";
  caveman-compress = "${src}/caveman-compress";
}
