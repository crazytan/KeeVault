# STATUS.md — KeeVault Project Status

**Last updated:** 2026-02-22

## Current State

🚀 **v1.1.0 ready for App Store submission**

- Bundle ID: `com.keevault.app`
- Version: 1.1.0 (build 2)
- iPhone only (v1)

## v1.1.0 Changes
- ✅ Fixed inner stream decryption — passwords now display correctly
- ✅ Fixed TOTP parsing from otp:// custom property
- ✅ Replaced vendored argon2 C code with Argon2Swift SPM package
- ✅ Fixed search — no longer dismisses on typing, works on all pages
- ✅ Fixed duplicate entries from History elements
- ✅ Face ID required to reveal/copy passwords
- ✅ No lock shield flash during biometric authentication
- ✅ Fixed launch screen placeholder icon
- ✅ Resolved Xcode warnings

## App Store Links
- **Privacy Policy:** https://gist.github.com/crazytan/afe07aecf77d2aea2664b4af79d70e0d#file-privacy-policy-md
- **Support:** https://gist.github.com/crazytan/afe07aecf77d2aea2664b4af79d70e0d#file-index-md

## Next Steps
- Submit v1.1.0 to App Store
- v1.2: AutoFill improvements (Safari, subtitle in Settings)
- v2 roadmap: editing, sync, attachments, iPad support
