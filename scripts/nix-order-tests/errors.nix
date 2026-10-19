{
  a = { # On the opening line.
    x = 1;
    y = 2;
  };

  b = {
    x = 1;
    # Belongs to no attribute.

    y = 2;
  };

  c = {
    x = 1;
    y = 2;
    # After the last attribute.
  };
}
