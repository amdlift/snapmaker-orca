{
  stdenv,
  lib,
  fetchFromGitHub,

  cmake,
  pkg-config,

  boost183,
  onetbb,
  freetype,
  libGL,
  glfw,
  eigen,
  expat,
  cereal,
  nlopt,
  openvdb,
  ilmbase,
  cgal_5,
  gmp,
  mpfr,
  opencv,
  opencascade-occt_7_6,
  libjpeg,
  libnoise,
  wxwidgets_3_1,
  glib,
  libX11,

  libmspack,
  gst_all_1,
  libsecret,
  webkitgtk_4_0,
  mesa,
  openssl,
  curl,
  dbus,
  extra-cmake-modules,
  gtk3,
  glew,
  git,
  texinfo
}:

let
  wxGTK' =
    (wxwidgets_3_1.override {
      withCurl = true;
      withPrivateFonts = true;
      withWebKit = true;
    }).overrideAttrs
      (old: {
        configureFlags = old.configureFlags ++ [
          # Disable noisy debug dialogs
          "--enable-debug=no"
        ];
      });
in
stdenv.mkDerivation rec {
  pname = "snapmaker-orcaslicer";
  version = "2.2.4";

  src = fetchFromGitHub {
    owner = "Snapmaker";
    repo = "OrcaSlicer";
    tag = "v${version}";
    hash = "sha256-qK4etfhgha0etcKT9f0og9SI9mTs9G/qaG/jl+44qo8=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    wxGTK'
  ];

  buildInputs = [
    dbus
    boost183
    onetbb
    openssl
    curl
    freetype
    libGL
    glib
    glew
    glfw
    eigen
    expat
    cereal
    nlopt
    openvdb
    ilmbase
    cgal_5
    gmp
    mpfr
    opencv
    opencascade-occt_7_6
    libjpeg
    libnoise
    wxwidgets_3_1
    gtk3
    libsecret
    gst_all_1.gstreamer
    libX11
  ];

  patches = [
    # Fix for webkitgtk linking
    # ./patches/0001-not-for-upstream-CMakeLists-Link-against-webkit2gtk-.patch
    # Link opencv_core and opencv_imgproc instead of opencv_world
    ./patches/dont-link-opencv-world-orca.patch
    # The changeset from https://github.com/SoftFever/OrcaSlicer/pull/7650, can be removed when that PR gets merged
    # Allows disabling the update nag screen
  ];

  prePatch = ''
    sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/PerimeterGenerator.cpp
    sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/Feature/FuzzySkin/FuzzySkin.cpp
  '';

  cmakeFlags = [
    (lib.cmakeBool "Boost_USE_STATIC_LIBS" false)
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.13")
    (lib.cmakeFeature "LIBNOISE_INCLUDE_DIR" "${libnoise}/include/noise")
    (lib.cmakeFeature "LIBNOISE_LIBRARY" "${libnoise}/lib/libnoise-static.a")
    (lib.cmakeBool "SLIC3R_STATIC" false)
    (lib.cmakeBool "SLIC3R_FHS" true)
    (lib.cmakeFeature "SLIC3R_GTK" "3")
    (lib.cmakeFeature "CMAKE_C_FLAGS" "-std=gnu11")
  ];

  env = {
    NIX_CFLAGS_COMPILE = toString (
      [
        "-Wno-ignored-attributes"
        "-I${opencv.out}/include/opencv4"
        "-Wno-error=incompatible-pointer-types"
        "-Wno-template-id-cdtor"
        "-Wno-uninitialized"
        "-Wno-unused-result"
        "-Wno-deprecated-declarations"
        "-Wno-use-after-free"
        "-Wno-format-overflow"
        "-Wno-stringop-overflow"
        "-DBOOST_ALLOW_DEPRECATED_HEADERS"
        "-DBOOST_MATH_DISABLE_STD_FPCLASSIFY"
        "-DBOOST_MATH_NO_LONG_DOUBLE_MATH_FUNCTIONS"
        "-DBOOST_MATH_DISABLE_FLOAT128"
        "-DBOOST_MATH_NO_QUAD_SUPPORT"
        "-DBOOST_MATH_MAX_FLOAT128_DIGITS=0"
        "-DBOOST_CSTDFLOAT_NO_LIBQUADMATH_SUPPORT"
        "-DBOOST_MATH_DISABLE_FLOAT128_BUILTIN_FPCLASSIFY"
      ]
      # Making it compatible with GCC 14+, see https://github.com/SoftFever/OrcaSlicer/pull/7710
      ++ lib.optionals (stdenv.cc.isGNU && lib.versionAtLeast stdenv.cc.version "14") [
        "-Wno-error=template-id-cdtor"
      ]
    );
  };

}