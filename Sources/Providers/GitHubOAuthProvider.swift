import SafariServices
import UIKit

let authorizeURL = URL(string: "https://github.com/login/oauth/authorize")!
let createAccessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
let redirectURI = "finchui://oauth/github/code"

final class GitHubOAuthProvider: FinchProvider {
  static let identifier = "com.thoughtbot.finch.github.oauth"

  let clientId: String
  let clientSecret: String

  private var currentAuthorization: (
    safariViewController: SFSafariViewController,
    completionHandler: (String?) -> Void
  )?

  init(clientId: String, clientSecret: String) {
    self.clientId = clientId
    self.clientSecret = clientSecret
  }

  func authorize(over viewController: UIViewController, completionHandler: @escaping (String?) -> Void) {
    precondition(currentAuthorization == nil)

    var authorizeURLComponents = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
    authorizeURLComponents.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
    ]

    let safariViewController = SFSafariViewController(url: authorizeURLComponents.url!)
    currentAuthorization = (safariViewController, completionHandler)
    viewController.present(safariViewController, animated: true)
  }

  func handleCallback(_ url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let query = components.queryItems,
      let codeParam = query.first(where: { $0.name == "code" }),
      let code = codeParam.value
      else { return false }

    var params: [URLQueryItem] = []
    params.append(URLQueryItem(name: "code", value: code))
    params.append(URLQueryItem(name: "client_secret", value: clientSecret))
    params.append(URLQueryItem(name: "client_id", value: clientId))

    var requestComponents = URLComponents()
    requestComponents.queryItems = params

    let requestQuery = requestComponents.query!
    let requestBody = requestQuery.data(using: .utf8)!

    var request = URLRequest(url: createAccessTokenURL)
    request.httpBody = requestBody
    request.httpMethod = "POST"

    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      self?.handleAuthorizationResponse(data, response, error)
    }

    task.resume()

    return true
  }

  private func handleAuthorizationResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
    guard let authorization = self.currentAuthorization else { return }

    defer { currentAuthorization = nil }

    var tokenResult: String?

    defer {
      DispatchQueue.main.async { [authorization] in
        authorization.safariViewController.dismiss(animated: true) {
          authorization.completionHandler(tokenResult)
        }
      }
    }

    guard error == nil else {
      return
    }

    let response = data.flatMap { String(data: $0, encoding: .utf8) }

    var components = URLComponents()
    components.query = response

    guard let token = components.queryItems?.first(where: { $0.name == "access_token" })?.value else {
      return
    }

    tokenResult = token
  }
}