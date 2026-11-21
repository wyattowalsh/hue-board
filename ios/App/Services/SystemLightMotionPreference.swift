import Foundation
import MediaAccessibility
import Observation

@MainActor
@Observable
final class SystemLightMotionPreference {
  static let didChangeNotification = kMADimFlashingLightsChangedNotification as NSNotification.Name
  private(set) var isEnabled = MADimFlashingLightsEnabled()

  func refresh() {
    isEnabled = MADimFlashingLightsEnabled()
  }
}
