import Dependencies
import Foundation
import HTTPRequestClient

#if DEBUG
  import Pulse

  // Pulse ships in DEBUG builds only. Release builds neither import nor link
  // it (see `pulseDebugOnly` in `Project+Templates.swift`), so the conformance
  // that lets the logging proxy act as a transport is DEBUG-only too.
  extension URLSessionProxy: @retroactive HTTPTransport {}
#endif

// The single transport every client in `Core` sends through. It is declared
// as a dependency rather than a global so the app gets one immutable session
// while tests override it through `withDependencies` — the same override seam
// the rest of the codebase uses.
//
// Every client under `Core/Sources/Clients` should pass
// `urlSession: networkSession` on its `HTTPRequestClient` calls so DEBUG builds
// capture all traffic in the shipped network console: only requests made on the
// `URLSessionProxy` session reach it.
public enum NetworkSessionKey: DependencyKey {
  public static let liveValue: any HTTPTransport = {
    #if DEBUG
      return URLSessionProxy(configuration: .default)
    #else
      return URLSession(configuration: .default)
    #endif
  }()

  // No `testValue`: the library default reports an issue when a test reaches
  // the session without overriding it, which is the behavior we want.
}

extension DependencyValues {
  public var networkSession: any HTTPTransport {
    get { self[NetworkSessionKey.self] }
    set { self[NetworkSessionKey.self] = newValue }
  }
}
