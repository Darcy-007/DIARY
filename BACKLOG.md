# dAIry Backlog

## Pending Items

- [ ] Re-enable `health-records` HealthKit entitlement once a paid Apple Developer account ($99/year) is available. Update `dAIry/dAIry.entitlements` to add `health-records` back to `com.apple.developer.healthkit.access` array, and update `project.yml` accordingly. This enables access to clinical health records (doctor visits, lab results, medications) for richer diary entries.

- [ ] Add multi-language support (Chinese and English). This involves:
  - Add a language picker in Settings (English / 中文)
  - Store the user's language preference in UserDefaults
  - Create `Localizable.strings` files for `en` and `zh-Hans` with all UI strings
  - Replace all hardcoded UI strings with `NSLocalizedString` / `String(localized:)` calls
  - Update the Gemini prompt to include a language instruction (e.g., "Write the diary entry in Chinese" / "Write the diary entry in English") based on the user's preference
  - Localize Info.plist usage descriptions for both languages
