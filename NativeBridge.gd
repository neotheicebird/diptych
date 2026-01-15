extends NativeBridge

# EDUCATIONAL:
# This script extends the C++ NativeBridge class defined in our GDExtension.
# 
# INTENT:
# Even though the logic is in C++, extending it in GDScript provides a "friendly"
# wrapper that can be easily registered as a Godot Autoload (Singleton).
# This allows us to access the C++ logic globally using the name 'Native' (defined in project.godot).
#
# ARCHITECTURE:
# This pattern (C++ Core -> GDScript Wrapper -> Godot Engine) keeps the boundary clean.
# Use this script for any light glue code or signals that are tedious to bind in C++.