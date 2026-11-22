import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, URLSessionTaskDelegate {
  private let origin = URL(string: "https://apex-resolve-one.vercel.app")!
  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.httpShouldSetCookies = false
    config.timeoutIntervalForRequest = 30
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }()

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterMethodChannel(name: "apex/session", binaryMessenger: messenger).setMethodCallHandler {
      [weak self] call, result in self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getStorageDir" {
      let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      result(urls.first?.path ?? "")
      return
    }
    if call.method == "logout" {
      let store = WKWebsiteDataStore.default().httpCookieStore
      store.getAllCookies { cookies in
        let group = DispatchGroup()
        for cookie in cookies where cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == self.origin.host {
          group.enter(); store.delete(cookie) { group.leave() }
        }
        group.notify(queue: .main) { result(true) }
      }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let path: String
    var httpMethod = "POST"
    switch call.method {
    case "chat": path = "/api/chat/session"
    case "login": path = "/api/auth/firebase"
    case "directory":
      guard let section = args["section"] as? String, ["chats", "groups", "issues", "knowledge"].contains(section) else {
        result(FlutterError(code: "SECTION", message: "Unknown directory", details: nil))
        return
      }
      path = "/api/mobile/directory?section=\(section)"
      httpMethod = "GET"
    case "api":
      guard let p = args["path"] as? String else {
        result(FlutterError(code: "PATH", message: "Missing path", details: nil))
        return
      }
      path = p
      httpMethod = ((args["method"] as? String) ?? "GET").uppercased()
    default: result(FlutterMethodNotImplemented); return
    }
    guard let url = URL(string: path, relativeTo: origin)?.absoluteURL else { return }
    let store = WKWebsiteDataStore.default().httpCookieStore
    store.getAllCookies { cookies in
      var request = URLRequest(url: url)
      request.httpMethod = httpMethod
      request.setValue(self.origin.absoluteString, forHTTPHeaderField: "Origin")
      let scoped = cookies.filter {
        $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == self.origin.host &&
        url.path.hasPrefix($0.path) && ($0.expiresDate ?? .distantFuture) > Date()
      }
      if scoped.isEmpty && call.method != "login" {
        result(FlutterError(code: "SIGN_IN", message: "Sign in to your workspace.", details: nil))
        return
      }
      for (key, value) in HTTPCookie.requestHeaderFields(with: scoped) { request.setValue(value, forHTTPHeaderField: key) }
      if httpMethod != "GET" {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = (args["data"] as? [String: Any]) ?? args
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
      }
      self.session.dataTask(with: request) { data, response, _ in
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let data = data, let body = String(data: data, encoding: .utf8) else {
          let code = (response as? HTTPURLResponse)?.statusCode == 401 ? "SIGN_IN" : "UNAVAILABLE"
          result(FlutterError(code: code, message: "Unable to open workspace session.", details: nil)); return
        }
        let headers = response.allHeaderFields as? [String: String] ?? [:]
        let group = DispatchGroup()
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: headers, for: url) {
          group.enter(); store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { result(body) }
      }.resume()
    }
  }
}
