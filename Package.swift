// swift-tools-version:5.3
//
//  Package.swift
//  FBUtility
//
//  Created by Stéphane Peter on 7/6/22.
//  Copyright © 2022 Catloaf Software, LLC. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "FBUtility",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "FBUtility",
            targets: ["FBUtility"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "14.0.0")
    ],
    targets: [
        .target(
            name: "FBUtility",
            path: "FBUtility"
        ),
        .testTarget(
            name: "FBUtilityTests",
            dependencies: ["FBUtility"],
            path: "FBUtilityTests"
        )
    ]
)
