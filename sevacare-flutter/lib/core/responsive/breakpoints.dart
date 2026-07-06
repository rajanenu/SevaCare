/// Width cutoffs (logical pixels) used to switch the app between the mobile
/// phone layout and wider tablet/desktop layouts.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

enum ScreenSize { mobile, tablet, desktop }

ScreenSize screenSizeOf(double width) {
  if (width >= Breakpoints.desktop) return ScreenSize.desktop;
  if (width >= Breakpoints.mobile) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

/// Max width for the app's centered content column. Below [Breakpoints.mobile]
/// this must stay 520 so the phone layout is pixel-identical to before.
double contentMaxWidthFor(double width) {
  switch (screenSizeOf(width)) {
    case ScreenSize.mobile:
      return 520;
    case ScreenSize.tablet:
      return 760;
    case ScreenSize.desktop:
      return 1040;
  }
}

/// Grid column count for the given viewport width — replaces hardcoded
/// `crossAxisCount` values so grids gain extra columns on wider screens.
int columnsForWidth(
  double width, {
  int mobileCols = 2,
  int tabletCols = 3,
  int desktopCols = 4,
}) {
  switch (screenSizeOf(width)) {
    case ScreenSize.mobile:
      return mobileCols;
    case ScreenSize.tablet:
      return tabletCols;
    case ScreenSize.desktop:
      return desktopCols;
  }
}
