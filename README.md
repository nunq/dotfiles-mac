# macOS dotfiles

## Text Replacements

The exported macOS text replacement list is stored as `private_textreplacements.plist` in this chezmoi source. Chezmoi maps it to `~/textreplacements.plist` and installs it with private file permissions when applied.

### Export

1. Open **System Settings → Keyboard → Text Replacements**.
2. Choose **Edit → Select All** (or select only the replacements you want).
3. Drag the selected rows from the Text Replacements window to the Desktop. macOS creates `property list.plist`.
4. Replace this repo's `private_textreplacements.plist` with the exported file.

### Import

1. Open **System Settings → Keyboard → Text Replacements** on the Mac to configure.
2. Drag `~/textreplacements.plist` from Finder onto the Text Replacements list.
3. Click **Done**.

Apple's instructions: [Back up and share text replacements on Mac](https://support.apple.com/en-mt/guide/mac-help/mchl2a7bd795/27/mac/27).
