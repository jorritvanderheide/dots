{
  pkgs,
  lib,
  ...
}:
{
  # About this set as a whole.
  #
  # Two paragraphs of it.

  zed = pkgs.writeText "a-long-name"
    "a long plain value that nixfmt wrapped onto a second line";
  bar = if lib ? x then 1 else 2;
  foo =
    if lib ? x then
      1
    else
      2;
  apple = 1;
}
