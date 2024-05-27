// swift-tools-version: 5.7
import Foundation
import PackageDescription

let package = Package(
  name: "Aspects",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "Aspects",
      targets: ["Aspects"]),
  ],
  targets: [
    .target(
      name: "Aspects")
  ],
  swiftLanguageVersions: [.v5]
)

if ProcessInfo.processInfo.environment["DEVELOPMENT"] != nil {
  for target in package.targets {
    target.swiftSettings = [
      .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]),
      .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"]),
    ]
  }
}
