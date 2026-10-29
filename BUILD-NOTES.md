# YouTube 21.43.5 / uYouPlus experimental build

This is build preparation based on qnblackcat/uYouPlus, not a verified
YouTube 21.x compatibility port. No device compatibility is claimed.

The source repository must not contain YouTube IPAs, extracted Payload folders,
signing certificates, passwords, or access tokens. The pre-existing uYou binary
dependency remains upstream's closed-source dependency; this repository does not
make that component open source.

## GitHub setup

1. Publish this source tree to a public repository, preserving submodules.
2. Create a separate **private** repository for the provided input IPA.
3. Upload the input there as release asset `youtube.ipa` under tag `youtube-input`.
4. In the source repository configure Actions secrets:
   - `INPUT_REPO`: private repository in owner/name format.
   - `INPUT_TOKEN`: fine-grained token with Contents read permission for only
     the private input repository.
5. Run **Build unsigned uYouPlus** manually.
6. Download `uYouPlus-21.43.5-unsigned`, extract it, and sign the IPA locally.

No p12 certificate is needed in GitHub. Workflow logs and artifacts in a public
repository should not be treated as private. IPA artifacts expire after 3 days;
no public release containing the IPA is created by this workflow.

## Changes from upstream

- Replace retired macos-13 runner with macos-15.
- Remove placeholder uYou download URL; use the committed upstream uYou 3.0.4 deb.
- Remove nonexistent YoutubeSpeed.dylib from the injection list.
- Pass YouTube version to make instead of modifying Makefile by line number.
- Fetch the exact hash-checked input from a separate private repository.
- Check main-executable encryption flags, embedded dependencies, and injection.
- Preserve upstream submodule revisions instead of blindly updating all plugins.

## Validation status

Local input metadata: YouTube 21.43.5, minimum iOS 17.0, cryptid=0.
SHA256: 9399201c85b5ec7747ac12870678abc938251470a5ea8476e8c9c9caa18e58eb

Cloud compilation and device testing are pending. Static checks do not establish
that runtime hooks match YouTube 21.43.5. Playback, sign-in, ad removal, Shorts,
background audio, and settings must be checked on the target iPhone.
