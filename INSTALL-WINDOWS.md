# Install FIELD/OS Swift on an iPhone from Windows (no Mac or paid Apple account)

## First: download the right build

**Do not use `FIELD-iOS-simulator.zip` on Windows or on a physical iPhone.** That file only runs in the Apple Simulator inside Xcode on a Mac.

Instead, use the separate [Free unsigned iPhone IPA](https://github.com/emdubr/swift/actions/workflows/ios-device-ipa.yml) workflow:

1. Open the link above, choose **Run workflow**, select **main**, and start it. It runs on the repository's **standard macOS-15 runner**; do not switch to a billed, larger runner. GitHub documents standard hosted runner minutes as free for public repositories.
2. When the workflow has a green check, open its run and, at the bottom under **Artifacts**, download **FIELD-iOS-unsigned-iPhone-IPA**.
3. Extract the downloaded GitHub artifact ZIP. Inside is **FIELD-iOS-unsigned.ipa**. The IPA is unsigned *by design*; do not try to double-click it or run it on Windows.

**Privacy/cost:** This GitHub workflow uses no Apple ID, signing credentials, subscription, or secret. It does not upload the package to a third-party build service. Build artifacts expire after one day to minimize GitHub storage use. Keep this repository public and leave the runner set to `macos-15` (standard, not paid/larger). Check your GitHub billing settings if you later change the repository to private.

## Install from Windows with a free Apple ID

1. Download **Sideloadly** from its official site: https://sideloadly.io/ . Follow its Windows instructions. Its site says the **web-download versions** of Apple iTunes and iCloud are required on Windows, not Microsoft Store versions.
2. Connect your iPhone to your PC with a USB data cable, unlock it, and tap **Trust** if asked.
3. Open Sideloadly and select the extracted **FIELD-iOS-unsigned.ipa**.
4. In Sideloadly, choose **Apple ID sideload** and authenticate with your **own free Apple ID on your own PC**. **Never provide your Apple ID password, app-specific passwords, or signing certificates in GitHub Issues, Actions secrets, or ChatGPT.** Sideloadly performs local free-account signing and installation; follow its own current security instructions.
5. On the iPhone, enable **Developer Mode** if prompted (Settings → Privacy & Security → Developer Mode) and trust your personal developer profile if prompted (Settings → General → VPN & Device Management). Follow current iOS prompts to open FIELD/OS.
6. Free Apple-ID-installed apps usually expire after **seven days** and must be refreshed or reinstalled with the **same Apple ID and bundle identifier**. Sideloadly offers automatic refresh with a paired Windows PC.

Reference: https://sideloadly.io/faq

## What works, what does not

- The iPhone IPA runs native iOS **if** it compiles successfully and Sideloadly signs/installs it with your Apple ID. It is **not** a Windows executable; your Windows PC acts as an installer.
- The existing live web FIELD/OS remains a separate product and is the way to use FIELD/OS *inside a Windows browser* while developing native Swift.
- Import appropriately licensed offline PMTiles/trail files on the device to get offline maps and routing. The IPA does not bundle all-world offline maps.
- Some system capabilities (especially WeatherKit entitlements, restricted background operations, and accessory-specific BLE protocols) may need additional signing capabilities or real-device tests. A cloud build cannot prove those work on a specific phone.
- **Navigation and messaging are not verified emergency systems.** Carry a proven emergency communicator and independently check navigation conditions.

## Troubleshooting

- **Downloaded the ZIP but nothing runs:** Did you get `FIELD-iOS-simulator` instead of `FIELD-iOS-unsigned-iPhone-IPA`? The simulator app is Mac-only; follow the IPA steps above.
- **Workflow is red:** Open the job log. Device builds may expose iOS framework or package-resolution problems not seen in simulator builds. Do not assume the IPA exists until the action reports a green success.
- **Sideloadly does not detect the phone:** Follow its official Windows web iTunes/iCloud installation and USB **Trust** instructions.
- **App opens but a feature is blank:** Check iOS permission prompts. Imported regional map packs are required for offline basemaps. A built IPA is not proof of successful on-device operation.
