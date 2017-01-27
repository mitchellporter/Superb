import Dispatch

/// Wraps some `Base` type so that all method calls become
/// "message sends", e.g., `async { $0.foo() }` or `sync { $0.bar() }`.
public final class Actor<Base> {
  private var instance: Base
  private let queue: DispatchQueue

  public init(_ instance: Base, target: DispatchQueue? = nil) {
    self.instance = instance
    self.queue = DispatchQueue(label: "com.thoughtbot.finch.\(Actor.self).queue", target: target)
  }

  public func sync<Result>(_ message: (inout Base) throws -> Result) rethrows -> Result {
    return try queue.sync {
      try message(&instance)
    }
  }
}