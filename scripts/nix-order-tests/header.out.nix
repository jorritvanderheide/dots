{
  lib,
  pkgs,
  ...
}:
{
  # About this set as a whole.
  #
  # Two paragraphs of it.

  apple = 1;
  bar = if lib ? x then 1 else 2;
  zed = pkgs.writeText "a-long-name"
    "a long plain value that nixfmt wrapped onto a second line";

  foo =
    if lib ? x then
      1
    else
      2;
}
