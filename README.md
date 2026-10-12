# ETF Rebalancer

A small macOS app that works out what to buy with a deposit to bring an ETF portfolio back to its target equity/bonds split. Prices come from justETF by ISIN and refresh every 5 minutes (⌘R to refresh now).

## Build

```sh
./scripts/build-app.sh            # builds build/ETF Rebalancer.app
./scripts/build-app.sh --install  # also copies it to /Applications
swift test
```

Requires macOS 14+ and Xcode (Swift 6).

## How it works

- Each ETF has a share count and a class (equity or bonds). The target is set only for the equity/bonds split, with the slider; the cash target is 0.
- "Suggest Buys" fills "To buy" with whole shares, without selling, to bring equity and bonds closest to the split. ETFs in the same class are treated as interchangeable: it buys whichever ETF best closes that class's gap, and the cheaper one tops up the remainder.
- "To buy" can also be edited by hand. Every number updates live, as in the spreadsheet.

Data is saved to `~/Library/Application Support/ETF Rebalancer/portfolio.json`.

## Disclaimer

Prices come from justETF's public website, which has no official API and may change without notice. This project isn't affiliated with justETF, and nothing it shows is financial advice.

MIT licensed. See [LICENSE](LICENSE).
