# Releasing TextPort

Use this checklist for public GitHub releases.

## 1. Prepare

- Update `CHANGELOG.md`.
- Confirm `CFBundleShortVersionString` and `CFBundleVersion` in `Packaging/Info.plist`.
- Confirm `README.md`, `SECURITY.md`, and `CONTRIBUTING.md` still match the app.

## 2. Verify

```sh
swift build
./script/build_and_run.sh --verify
```

Manual checks:

- Open a plain text file.
- Open a Markdown file and toggle preview.
- Open a PDF, Word document, PowerPoint deck, and workbook sample.
- Open a folder project and run a harmless task.
- Confirm Finder-opened files join the existing TextPort window as tabs.

## 3. Package

```sh
./Scripts/package-app.sh
```

This creates `TextPort.app` in the project folder. For broad distribution, sign and notarize the app with an Apple Developer ID before attaching it to a release.

## 4. Publish

- Commit the release changes.
- Tag the release, for example `v1.0.0`.
- Create a GitHub Release from the tag.
- Attach the signed/notarized app bundle archive when available.
- Copy the release notes from `CHANGELOG.md`.
