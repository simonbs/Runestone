//
//  AppDelegate.swift
//  Example
//
//  Created by Simon on 19/01/2022.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UserDefaults.standard.registerDefaults()
        return true
    }
}
