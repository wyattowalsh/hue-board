import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func startEventMonitoring() {
    guard eventTask == nil, isReady, let profile, let credential else { return }
    eventTask = Task { [weak self] in
      guard let self else { return }
      var retrySeconds = 1.0
      defer {
        self.eventStreamConnected = false
        self.eventTask = nil
      }

      while !Task.isCancelled {
        let stream = await self.eventClient.stream(
          profile: profile,
          credential: credential
        )
        do {
          for try await batch in stream {
            try Task.checkCancellation()
            retrySeconds = 1
            self.eventStreamConnected = true
            self.lastEventAt = Date()
            self.applyEventBatch(batch)
          }
          try Task.checkCancellation()
          throw HueBoardError.network("The Hue event stream ended unexpectedly.")
        } catch is CancellationError {
          return
        } catch {
          self.eventStreamConnected = false
          guard !Task.isCancelled else { return }
          self.note = "Bridge push updates disconnected. Retrying without sending light commands."
          try? await Task.sleep(for: .seconds(retrySeconds))
          retrySeconds = min(retrySeconds * 2, 30)
        }
      }
    }
  }

  func stopEventMonitoring() {
    eventTask?.cancel()
    eventTask = nil
    eventRefreshTask?.cancel()
    eventRefreshTask = nil
    eventStreamConnected = false
  }

  private func applyEventBatch(_ batch: HueEventBatch) {
    let lightUpdates = Dictionary(
      grouping: batch.resources.filter { $0.type == "light" },
      by: \.id
    )
    if !lightUpdates.isEmpty {
      areas = areas.map { area in
        let updatedLights = area.lights.map { light in
          lightUpdates[light.id, default: []].reduce(light) { current, event in
            current.applying(event)
          }
        }
        return HueArea(
          id: area.id,
          kind: area.kind,
          name: area.name,
          lights: updatedLights
        )
      }
    }
    if batch.requiresInventoryRefresh {
      scheduleInventoryRefreshFromEvents()
    }
  }

  private func scheduleInventoryRefreshFromEvents() {
    eventRefreshTask?.cancel()
    eventRefreshTask = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: .milliseconds(750))
      guard !Task.isCancelled else { return }

      var attempts = 0
      while self.isBusy, attempts < 10, !Task.isCancelled {
        attempts += 1
        try? await Task.sleep(for: .milliseconds(500))
      }
      guard !Task.isCancelled, !self.isBusy,
        let profile = self.profile,
        let credential = self.credential
      else { return }

      do {
        let values = try await self.client.inventory(
          profile: profile,
          credential: credential
        )
        guard self.profile?.bridgeID == profile.bridgeID else { return }
        self.areas = values
        if !values.contains(where: { $0.id == self.selectedAreaID }) {
          self.selectedAreaID = values.first?.id
          await self.persistence.saveSelectedAreaID(
            self.selectedAreaID,
            bridgeID: profile.bridgeID
          )
        }
      } catch {
        self.note = "A structural Bridge change was reported, but inventory refresh failed: \(error.localizedDescription)"
      }
      self.eventRefreshTask = nil
    }
  }
}
