{ inputs, lib }:

let
  src = inputs.caveman;

  renderCommand =
    fileName: commandName:
    let
      upstream = builtins.fromTOML (builtins.readFile "${src}/commands/${fileName}.toml");
    in
    {
      ${commandName} = ''
        ---
        description: ${upstream.description}
        ---

        ${upstream.prompt}
      '';
    };
in
lib.foldl' lib.recursiveUpdate { } [
  (renderCommand "caveman" "caveman")
  (renderCommand "caveman-commit" "caveman-commit")
  (renderCommand "caveman-review" "caveman-review")
]
