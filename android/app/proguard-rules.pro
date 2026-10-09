# Project-specific ProGuard/R8 rules.
#
# Flutter's own Gradle plugin already ships default keep rules for the
# engine, plugin registrant, and most first-party plugins used here (dio,
# flutter_secure_storage, go_router, image_picker, open_filex,
# path_provider, cached_network_image, google_fonts, url_launcher). Add
# rules below only if a `flutter build apk --release` / `--split-debug-info`
# run turns up a missing-class crash that a debug build didn't show.
