# BuyWise

BuyWise is an iOS shopping companion that helps users compare electronics prices across Sri Lankan retailers (Singer and Abans), track price drops, and judge whether a product is good value before buying.

## Features

- **Search & compare** — search smartphones, laptops and headphones and compare prices across retailers side by side
- **Value Score** — a 0–10 score combining specs-for-price, price position and price history
- **Price history** — 30/60/90-day price charts with lowest, highest and current price
- **Price tracking** — track products and get notified when prices drop
- **Product identification** — find products by barcode scan, photo/price-tag scan, or pasting a retailer link
- **Upgrade analysis** — compare a device you own with one you're considering
- **Nearby retailers** — find the closest Singer and Abans branches on a map
- **Authentication** — email sign in, Sign in with Apple, Google sign in and Face ID
- **Appearance** — light, dark and system themes

## Tech Stack

- Swift / SwiftUI
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
├── Models/               # App state and data models
├── MockData/             # Product catalog, store branches and price history
├── Services/             # Pricing, value score, matching, scanning, location, notifications
├── Utilities/            # Colors, typography, theme and formatters
├── Views/                # SwiftUI screens grouped by feature
│   └── Components/       # Reusable UI components
└── Assets.xcassets/      # App icon, brand logos and product images
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

> The app currently runs on bundled demo data — product prices, retailers and store branches are mock data.
