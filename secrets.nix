let
  dpc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZjH1c5py2OnIp6YhSwoYeG91gfRNRl4fL+hIHaI1Ej dpc@ren";
  users = [ dpc ];

  runner-01 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCpwKE1GREb41ii/T/WFzFNgb+pV8C43iW+BPV2dolDsSkyQ9GaENMU6n204T8xTOiU2af0ALvEs3jDTp+I9zxjNu+KvzOtlM7Glbhl1Xl2JsdFjdRQ5oyOhlVw+DUPz39u99RSDiwf35RnWQWIujIeZCtB3lZNLdYflsQNpEayxSBP2BNtd4knqjZmF0+ANgZw5fwguJptLCjBK7PnG0Ffto4KaAU6G9QzYhskiW2YjfT/48RLQc8FfGyaPc4JN8Sf/jjQJsxolWoLH/q/zjLdS6ifUi7bMhorJNe0kt/vCqbmkasy+HsRb5V1MgMc+/tBqcHBFNvM8ak55oWOyEZr+aeOxI4agf4nKvTdtwRSt62zLMLeaz3JebkX9n4yTGc131X6Cd2CzdUZRJL+NFzTRCtPkMUJ0YnhSQBmflw1CM7iJN4zRG1nbAOWo5dvE0j0PSd1aBasIfLY5EkHmt8AKxIeJNqwV8A64t6t2Yrzt4MrBUliFB9cqVs8aYNdjHZ7yozH2XLmnj6QH30dI8ZewLeIVxfBDwjqBO3wrHORu2I+hwd0WNklzVGNUDRKdX5Cp/Q+H51I1bvo93Vl2xS1cN5ZvqSg5FsgZb7KkEdFFwr1PDtTInI6b2YXCjnLF+kK43xhYVzeeeaFJ475K2kTFZMIy2JvF+xAv/AsgzNLZQ== root@nixos";
  systems = [ runner-01 ];
in
{
  "secrets/github-runner.age".publicKeys = systems ++ users;
}

