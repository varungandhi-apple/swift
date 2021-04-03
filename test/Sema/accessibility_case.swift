// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend %s -typecheck -swift-version 5 -enable-library-evolution -enable-experimental-enum-case-access-control -DTEST_LIBEVO_EXPORT -module-name test -emit-module-interface-path %t/test.swiftinterface
// RUN: %target-typecheck-verify-swift -swift-version 5 -enable-library-evolution -enable-experimental-enum-case-access-control -I %t -DTEST_LIBEVO_IMPORT_AND_DIAGNOSTICS

#if TEST_LIBEVO_EXPORT
@frozen
public enum PublicEnum {
  case publicCase
  internal case internalCase
  fileprivate case fileprivateCase
  private case privateCase
}
#endif

#if TEST_LIBEVO_IMPORT_AND_DIAGNOSTICS
import test

func f(_ publicEnum: PublicEnum) {
  switch publicEnum {
  case .publicCase: ()
  case .internalCase: () // expected-error{{'internalCase' is inaccessible due to 'internal' protection level}}
  case .fileprivateCase: () // expected-error{{'fileprivateCase' is inaccessible due to 'fileprivate' protection level}}
  case .privateCase: () // expected-error{{'privateCase' is inaccessible due to 'private' protection level}}
  }
}

fileprivate struct FileprivateStruct {}
  // expected-note@-1{{type declared here}}

public protocol PublicProtocol {
  static var protocolVar: Self { get }
}

@frozen
public enum BuggyPublicEnum: PublicProtocol {
  private case privateCase(FileprivateStruct)
  // expected-error@-1{{type of associated value in '@frozen' enum case must be '@usableFromInline' or public}}
  case publicCase
  internal case protocolVar
  // expected-error@-1{{case 'protocolVar' must be declared public because it matches a requirement in public protocol 'PublicProtocol'}}
  // expected-note@-2{{mark the enum case as 'public' to satisfy the requirement}}
}
#endif
