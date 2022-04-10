//
//  MenuController.swift
//  Restaurant
//
//  Created by Gleb Osotov on 4/10/22.
//

import Foundation
import UIKit

class MenuController {
    static let shared = MenuController()
    
    
    // MARK: API calls
    let baseURL = URL(string: "http://localhost:8080")!
    
    /// API call to get categories
    /// - Returns: String array of Category names
    func fetchCategories() async throws -> [String] {
        let categoriesURL = baseURL.appendingPathComponent("categories")
        let (data, response) = try await URLSession.shared.data(from: categoriesURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MenuControllerError.categoriesNotFound
        }
        
        let decoder = JSONDecoder()
        let categoriesResponse = try decoder.decode(CategoriesResponse.self, from: data)
        
        return categoriesResponse.categories
    }
    
    /// API call to get available menu items
    /// - Parameter categoryName: String name of category, get from `fetchCategories()`
    /// - Returns: List of `MenuItem` that represents items in menu in this category
    func fetchMenuItems(forCategory categoryName: String) async throws -> [MenuItem] {
        let baseMenuURL = baseURL.appendingPathComponent("menu")
        var components = URLComponents(url: baseMenuURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "category", value: categoryName)]
        let menuURL = components.url!
        let (data, response) = try await URLSession.shared.data(from: menuURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MenuControllerError.menuItemsNotFound
        }
        
        let decoder = JSONDecoder()
        let menuResponse = try decoder.decode(MenuResponse.self, from: data)
        
        return menuResponse.items
    }
    
    typealias MinutesToPrepare = Int
    
    /// Lets place an order and get preparation time in minutes
    /// - Parameter menuIDs: IDs from   `fetchMenuItems(forCategory categoryName: String)`
    /// - Returns: preparation time in minutes
    func submitOrder(forMenuIDs menuIDs: [Int]) async throws -> MinutesToPrepare {
        let orderURL = baseURL.appendingPathComponent("order")
        var request = URLRequest(url: orderURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let menuIdsDict = ["menuIds": menuIDs]
        let jsonEndoder = JSONEncoder()
        let jsonData = try? jsonEndoder.encode(menuIdsDict)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MenuControllerError.orderRequestFailed
        }
        
        let decoder = JSONDecoder()
        let orderResponse = try decoder.decode(OrderResponse.self, from: data)
        
        return orderResponse.prepTime
    }
    
    func fetchImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MenuControllerError.imageDataMissing
        }
        
        guard let image = UIImage(data: data) else {
            throw MenuControllerError.imageDataMissing
        }
        
        return image
    }
    
    // MARK: local order
    var order = Order() {
        didSet {
            NotificationCenter.default.post(name: MenuController.orderUpdatedNotification, object: nil)
        }
    }
    
    static let orderUpdatedNotification = Notification.Name("MenuController.orderUpdated")
    
    
    func scheduleNotification(minutesFromNow minutes: Int) {
        
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _  in
                if !granted {
                    return
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Your order is almost ready"
        content.body = "Have a good meal (in about 10 minutes)!"

        let trigger = UNCalendarNotificationTrigger(
             dateMatching: Calendar.current.dateComponents(
               [.day, .month, .year, .hour, .minute],
               from: Date.now.addingTimeInterval(TimeInterval(60 * minutes))),
             repeats: false)
        
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString,
                    content: content, trigger: trigger)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
           if error != nil {
              // Handle any errors.
           }
        }
    }
}

enum MenuControllerError: Error, LocalizedError {
    case categoriesNotFound
    case menuItemsNotFound
    case orderRequestFailed
    case imageDataMissing
}
