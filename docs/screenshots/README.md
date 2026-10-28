# README screenshots

These PNGs are captured from the running iPhone simulator by Flutter's
integration-test screenshot API. The test uses real Rust/OpenMLS operations;
no protocol state or error messages are mocked or composited.

- `phone-overview.png`: the initial group and invitation step.
- `phone-eviction.png`: the completed removal and decryption rejection.

To regenerate on a booted iPhone simulator, from `apps/mls_demo`:

```sh
flutter drive --driver=test_driver/screenshots.dart \
  --target=integration_test/screenshots_test.dart -d <simulator-id>
```

The driver saves files here. The current captures use an iPhone 17 Pro running
iOS 26.5. Device size, font rendering, and OS insets can affect the images.
Review new captures before committing them. Android capture is also supported
by the test, but the checked-in images are from iOS.
