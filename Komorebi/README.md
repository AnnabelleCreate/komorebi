# Komorebi · iOS beta (0.9)

Komorebi is a bedtime wind-down app for women 40–50: a few slow, culture-inspired rituals that each end by letting go, plus an optional physical kit. This folder is the native iOS beta, written in Swift and SwiftUI.

AIxD Project 3 · Hyunsuh (Matty) and team · Carnegie Mellon University

---

## How to open it

### Install the beta (testers)
**TestFlight link:** _add the public link here once the Apple Developer account is verified and the first build is uploaded (see "Releasing to TestFlight" below)._

1. Install **TestFlight** from the App Store on your iPhone.
2. Open the public link above on that iPhone and tap **Accept**, then **Install**.
3. Open Komorebi. It starts with three short questions you can skip.

Until the TestFlight link is live, the web beta works on any phone or laptop: [Komorebi Beta](https://claude.ai/artifact/SjWMUdGrHNkiCCw1BMt6YV).

### Build it yourself (team)
You need a Mac with **Xcode 16 or later** (Xcode 26 works too) and an iPhone on **iOS 17 or later**.

1. Open `Komorebi.xcodeproj`.
2. Select the **Komorebi** project in the sidebar. For **both** targets (Komorebi and KomorebiWidgets), open **Signing & Capabilities** and choose your **Team**.
   - If Xcode says the bundle ID is taken, change `edu.cmu.aixd.komorebi` to something unique (for example `edu.cmu.aixd.yourname.komorebi`) and make the widget's ID that same value plus `.widgets`.
   - If you change the App Group, change it in both `.entitlements` files in `Config/` and in `Shared/SharedModels.swift` (`appGroupID`).
3. Pick your iPhone (or an iPhone 16 Pro simulator) at the top and press **Run** (⌘R).

If `Komorebi.xcodeproj` won't open on your Xcode version, install XcodeGen (`brew install xcodegen`) and run `xcodegen` in this folder to rebuild the project from `project.yml`.

**Fonts.** Urbanist (titles), Prompt (body text) and Literata (serif reading) are bundled in `Komorebi/Resources/Fonts` and `KomorebiWidgets/Fonts` under the SIL Open Font License, so the app matches the Figma design system type scale: display 32, headings 28 / 24 / 20, body 18 / 16, caption 14.

### Without a paid Apple Developer account
You can still run Komorebi on your own iPhone with a free Apple ID ("Personal Team"). The app stops opening after 7 days and has to be re-installed from Xcode, and only phones plugged into your Mac can get it, so this doesn't meet beta check 1. Notifications, widgets and Live Activities still work.

### Releasing to TestFlight
1. In Xcode, choose **Any iOS Device (arm64)**, then **Product → Archive**.
2. In the Organizer, **Distribute App → TestFlight & App Store → Upload**.
3. In App Store Connect → your app → **TestFlight**, add the build to an **External Testing** group, fill in the test information, and submit it for Beta App Review (usually about a day).
4. Turn on the group's **Public Link** and paste it at the top of this README.

## Which device

An **iPhone** on **iOS 17 or later**, in portrait. It's designed at the iPhone 16 Pro size (402 × 874 pt) and adapts to other iPhones. The Dynamic Island and Live Activities need an iPhone 14 Pro or later; Lock Screen widgets work on any iPhone running iOS 17.

## What works

| Part | What it does |
| --- | --- |
| First-time setup | Three short questions (your name, text size, when evenings wind down), all skippable. |
| Tonight (home) | Greeting; a **Now playing / Paused** card for the story you were listening to (it stays after you pause or close the app); **Your go-to** favorite; tonight’s suggestion; the two rituals; and the **story shelf**: Mythology, Poems and Literature, with a swipeable carousel of covers. The Discover tab was removed, since everything now fits on Tonight. |
| Sand garden | Drag to rake around three stones, tap a stone for rings, or trace a ginkgo leaf, river or spiral. Steady touch smooths shaky hands. Smooth it away, or leave it: **your garden is saved and still there next time.** |
| Lantern release | Type one thought in a note below the lantern, watch the note fold and tuck into the lantern, then **blow into the microphone** (or press and hold, or tap). The lantern drifts up the river and slips behind the far bank on the horizon. The words are never saved. |
| Reading | Paged like the Figma reader: swipe or use the arrows to turn pages, see “Page 2 of 10 · 6 min left”, bookmark a page, and change size, serif or sans, warmth and dim slowly. **Your place is saved.** The last page is “The end.” with a line to keep. |
| Listening | Laid out like Figma: cover, scrubber, ±15 s, speed, **Stop playing** sleep timer (Off, End of story, 15, 30 min) that fades the voice out, **Still awake? Add time** (+5 / +15 min), and Turn screen off. Swipe down to close. **Read along:** the headphones button in the reader (or the book button here) highlights the sentence being narrated, dims the rest, and turns pages for you, like synced lyrics; tap a paragraph to jump there. Lock Screen controls and a **Live Activity** with working +15 min, Stop and pause buttons. |
| Kits | Kit of the month → How often → Bag → Shipping → Payment → Review → Confirmed, with real form checks. Orders are saved; monthly plans can be skipped, cancelled or restarted, with a reminder 3 days before each box. |
| Profile | Favorited activities (tap the star to make one your **go-to**), purchase history with a monthly-plan switch, and Settings. |
| Settings | Gear in the top-right of Profile. **Notification Preferences:** one wind-down schedule (Scheduled, every day or chosen days, from–until) that the widget follows, plus an optional quiet notification. **Widget:** choose which favorite the widget opens. **Accessibility:** text size, activity light, warm screen, reduce motion, steady touch, one-tap raking, tap instead of hold, sounds, ambience, volume, haptics. Lines you kept, orders, erase everything. |
| Widgets | Built from the V2 Figma frames. **Your go-to** (Home Screen small and medium, StandBy, Lock Screen) opens the activity you chose and says “Tonight” during your wind-down time. **Your story** shows the story you’re reading with minutes left and the gold progress ring. The sleep-timer **Live Activity** matches the Figma card. |

## The five beta checks

**1. You can get it yourselves.** Through the TestFlight public link once the developer account is verified (see above). Until then, the web beta link works on any device.

**2. It's hooked up to real things.**
- **Touch input:** raking, tracing and stone taps, with real-time smoothing (One Euro filter).
- **Microphone:** Lantern release listens for a breath. Only the loudness level is read; nothing is recorded or saved.
- **Audio:** real narration files, Lock Screen controls, background playback, interruptions (calls, unplugging headphones).
- **Notifications:** a real scheduled notification at the start of your wind-down time, and kit reminders.
- **Widgets and Live Activities:** real WidgetKit widgets and an ActivityKit Live Activity.
- **Haptics:** soft taps while raking and releasing.
- **Data:** everything is saved to a file on the phone.

**3. It remembers.** Close the app, swipe it away or restart the phone, and these are still there:
- your name, text size and every setting
- favorites
- reading places, listening positions and kept lines
- your sand garden
- orders and your saved address
- your prompt schedule

**4. It handles the unhappy path.**
- **First-time setup:** three short questions, each skippable.
- **Empty states:** no favorites, no purchases, no orders, no kept lines.
- **Bad input:** invalid address, state or ZIP; wrong card number (checked with the Luhn algorithm), expired card or bad security code. Each gets a clear inline error that VoiceOver also reads out.
- **Declined payments:** the test cards 4000 0000 0000 0002 (declined) and 4000 0000 0000 9995 (insufficient funds).
- **Permissions denied:** if notifications are off, Settings explains it and links to iPhone Settings. If the microphone is denied, the lantern falls back to press-and-hold. If Live Activities are off, playback continues normally.
- **Slow or failed connection:** Komorebi doesn't need a connection. Stories, narration, art and sounds are all inside the app, so it works in airplane mode.
- **Missing or damaged files:** a missing narration shows "Read the story instead". If the saved data is damaged, Komorebi starts fresh, keeps a backup, and says so. A failed save shows a notice.

**5. Anything faked is listed below and approved in advance.**

## What's still faked (for approval)

| Item | What happens in the beta | Why |
| --- | --- | --- |
| **Kit payment** | Test mode. The card form is fully checked, but no money is charged. 4242 4242 4242 4242 succeeds; the decline test cards fail. | Taking real money needs a payment provider account (for example Stripe), a server to hold the secret key, sales tax and refunds. Charging classmates and instructors real money for a class beta isn't appropriate. |
| **Apple Pay** | Not offered. | Apple Pay needs a paid developer account and a merchant ID. It can be added once payment is real. |
| **Kit shipping** | The order is saved for real. Its status (Ordered → Packed → On its way → On your nightstand) moves with the calendar. No box is actually sent. | We're preparing one example kit, not fulfilling orders. |
| **Read-along timing** | The highlighted sentence is estimated from the length of each sentence and the narration’s length (allowing for LibriVox’s short spoken introduction), so it can run a few seconds ahead or behind. Tapping a paragraph re-syncs it. | The LibriVox recordings don’t come with word-level timestamps. Aligning them exactly would need a speech-alignment pass we haven’t done yet. |
| **Accounts and sync** | Everything is saved on one phone only, with no sign-in and no cloud. | Privacy by design for a sleep app, and no server to run. Deleting the app deletes the data. |
| **Coloring, Patterns, Music** | Not in the iOS beta (still in the Figma prototype). | We cut the beta down to three activities done well. |

## Accessibility

- **VoiceOver:** every control has a label.
  - The sand garden allows direct touch, so you can double-tap and hold, then drag to rake.
  - It also has VoiceOver actions: rake a line, rings around each stone, trace the next part, smooth it away.
  - One-tap raking shows those same actions as on-screen buttons.
- **Dynamic Type:** text follows the iPhone's text size, plus Komorebi's own Standard / Large / Larger setting. Reading has its own five sizes.
- **Reduce Motion:** follows the iPhone setting by default and can be changed in Settings. Movement becomes soft fades, and raking, rings and the sweep happen at once.
- **Motor:**
  - Steady touch is set to Steadiest by default.
  - Tap instead of hold works anywhere a press-and-hold is used.
  - Every control's touch area is at least 44 pt.

## Change log since V2

| Date | Change | Why |
| --- | --- | --- |
| Nov 24 | Opening the app shows the Figma splash, which fades after about 1.2 seconds to reveal Tonight. | Match the prototype's first screen without making people wait. |
| Nov 24 | One full-screen loading layer (dark indigo with a gold ginkgo leaf circling at a steady pace) covers any wait longer than a moment: launch, opening a book, the sand garden, the narration. If the app ever freezes for more than a second, the layer covers the screen while it catches up. | Error states: people should always see that something is happening. It meets WCAG: no flashing, slow linear motion, still with Reduce Motion, high-contrast text, announced to VoiceOver. |
| Nov 24 | Book pages are laid out off the main thread. | Opening a long story or changing text size no longer risks freezing the screen. |
| Nov 24 | Richer sand speckle in the sand garden; removed the shuffle-path button. | A more tactile sand texture; tracing paths still advance on their own. |
| Nov 24 | 16 pt padding inside every widget and the Live Activity. | Text, images and buttons sat too close to the widget edges. |
| Nov 21 | Bundled Urbanist, Prompt and Literata and matched the Figma type scale. | The beta was falling back to system fonts; our design system uses Urbanist and Prompt. |
| Nov 21 | Removed the Discover tab; rituals and the story shelf now live on Tonight. Added a three-tab bar with the gold pill from Figma. | Only a few activities; one home is simpler. |
| Nov 21 | Favorites can be set as your **go-to**: it sits at the top of Tonight, and you can choose which favorite the widget opens. | Get to the activity you rely on in one tap. |
| Nov 21 | One wind-down schedule (Notification Preferences) drives the widget and an optional notification. The separate night prompt was removed. | Two settings did the same job. |
| Nov 21 | Reader and Listening rebuilt to match the Figma prototype: paged reader with swipes, read-along highlighting, swipe down to close the player, and a paused story that stays on Tonight. | Match the screens and motion we already designed and tested. |
| Nov 21 | Lantern: the note no longer covers the lantern; it folds into it; the river ends at the horizon where the lantern disappears. | Clearer story of letting go. |
| Nov 21 | Widgets and the sleep-timer Live Activity rebuilt from the V2 Figma frames, with working +15 min, Stop and pause buttons. | Match the prototype. |
| Nov 17 | Rebuilt as a native iOS app in Swift and SwiftUI, with a widget extension. | Beta checks 1–3: an installable app with real notifications, widgets, a Live Activity, microphone, audio and saved data. |
| Nov 17 | Evening and night prompts became real notifications, or a Lock Screen widget that changes at your chosen times. The night prompt never lights the screen. | Ethics audit: prompts only when chosen, and never waking anyone up. |
| Nov 17 | The lantern can be released by blowing into the microphone. | Critique asked for a breathing exercise. This makes the breath the action. |
| Nov 17 | Checkout gained real validation, test cards and decline handling. Monthly plans get a reminder 3 days before shipping, and can be skipped, cancelled or restarted from Profile. | Beta check 4, and the ethics audit's warning about subscriptions that are hard to cancel. |

| Nov 16 | Web beta: VoiceOver raking (one-tap raking), gentle fades with Reduce Motion, general accessibility settings, evening and night prompts. | VoiceOver and Reduce Motion testing on iPhone. |

Credits: story texts from Project Gutenberg; narration by LibriVox volunteers (public domain); interface sounds and art made for Komorebi.
