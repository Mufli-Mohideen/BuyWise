# BuyWise

BuyWise is an iOS shopping companion that helps users compare electronics prices across Sri Lankan retailers (Celltronics, Abans and Singer), track price drops, and judge whether a product is good value before buying.

## Features

- **Search & compare** — search smartphones, laptops and headphones and compare prices across retailers side by side
- **Value Score** — a 0–10 score combining specs-for-price, price position and price history
- **Price history** — 30/60/90-day price charts with lowest, highest and current price
- **Price tracking** — track products and get notified when prices drop
- **Product identification** — find products by barcode scan, photo/price-tag scan, or pasting a retailer link
- **Upgrade analysis** — compare a device you own with one you're considering
- **Comparison summary** — a T5 model fine-tuned for BuyWise runs on the iPhone with Core ML: see [ml/summarizer/README.md](ml/summarizer/README.md)
- **Nearby retailers** — find the closest Celltronics, Abans and Singer stores on a map
- **Authentication** — email sign in, Sign in with Apple, Google sign in and Face ID
- **Appearance** — light, dark and system themes

## Tech Stack

- Swift / SwiftUI
- Supabase (Postgres, Auth, Storage, Realtime): see [backend/README.md](backend/README.md)
- Core ML (fine-tuned T5-small summariser), Vision, Natural Language
- Swift Charts
- Vision & VisionKit (barcode and text recognition)
- NaturalLanguage (retailer listing matching)
- MapKit & Core Location
- UserNotifications
- LocalAuthentication (Face ID)

## Project Structure

```
BuyWise/
├── BuyWiseApp.swift      # App entry point
├── Backend/              # Supabase client, row types and the live catalogue store
├── Models/               # App state and data models
├── MockData/             # Reference devices for upgrade analysis
├── Services/             # Value score, matching, product finder, scanning, location, notifications
├── Utilities/            # Colors, typography, theme and formatters
├── Views/                # SwiftUI screens grouped by feature
│   └── Components/       # Reusable UI components
├── Resources/            # Core ML summary models and tokenizer vocabulary
└── Assets.xcassets/      # App icon, brand logos and product images
backend/                  # Supabase migrations, seed data and the Celltronics/Abans/Singer scraper
ml/summarizer/            # Training data, fine-tuning, evaluation and Core ML conversion for the summary model
```

## Requirements

- Xcode 26 or later
- iOS 26.5 or later

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/Mufli-Mohideen/BuyWise.git
   ```
2. Open `BuyWise.xcodeproj` in Xcode
3. Select an iPhone simulator or device and press **Run** (⌘R)

> Prices, specs and store locations come from a snapshot of the Celltronics, Abans and Singer websites stored in Supabase. Earlier price history is simulated for the demo. See [backend/README.md](backend/README.md) to deploy the backend.
