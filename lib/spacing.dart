/// App-wide spacing scale on a 4/8 grid. Use these instead of ad-hoc pixel
/// values so every page shares one rhythm (spacing audit, 2026-07-13).
///
/// The global page gap (top clearance below the safe-area inset, and the
/// white area above the nav-bar pill) is owned by main.dart. Individual
/// pages must NOT add their own top/bottom padding on top of it, or the gaps
/// stack and stop being uniform across pages.
class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
