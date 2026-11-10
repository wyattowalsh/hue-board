import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func startEventMonitoring() {
    guard eventTask == nil, isReady, let profile, let credential else { return }

    eventMonitorGeneration &+= 1
    let generation = eventMonitorGeneration
    eventStreamConnected = false
    eventStreamDetail = "Connecting to pinned Bridge push updates."

    eventTask = Task { [weak self] in
      guard let self else { return }
      var retrySeconds = 1.0
      defer {
        guard self.eventMonitorGeneration == generation else { return }
        self.eventStreamConnected = false
        self.eventTask = nil
        if self.isReady && self.eventStreamDetail.hasPrefix("Pinned event stream") {
          self.eventStreamDetail = "Push updates stopped."
        }
      }

      while !Task.isCancelled, self.eventMonitorGeneration == generation {
        let stream = await self.eventClient.stream(
          profile: profile,
          credential: credential
        )
        do {
          for try await message in stream {
            try Task.checkCancellation()
            guard self.eventMonitorGeneration == generation else { return }

            switch message {
            case .connected:
              retrySeconds = 1
              self.eventStreamConnected = true
              self.eventStreamDetail = "Pinned event stream connected."
            case .batch(let batch):
              retrySeconds = 1
              self.eventStreamConnected = true
              self.lastEventAt = Date()
              self.eventStreamDetail = "Receiving Bridge push updates."
              self.applyEventBatch(batch)
            }
          }
          try Task.checkCancellation()
          throw HueBoardError.network("The Hue event stream ended unexpectedly.")
        } catch is CancellationError {
          return
        } catch {
          guard self.eventMonitorGeneration == generation, !Task.isCancelled else { return }
          self.eventStreamConnected = false

          if self.isFatalEventStreamError(error) {
            self.eventStreamDetail = "Push updates stopped: \(error.localizedDescription)"
            return
          }

          self.eventStreamDetail =
            "Push updates disconnected. Retrying in \(Int(retrySeconds)) second(s)."
          do {
            try await Task.sleep(for: .seconds(retrySeconds))
          } catch {
            return
          }
          guard self.eventMonitorGeneration == generation else { return }
          retrySeconds = min(retrySeconds * 2, 30)
        }
      }
    }
  }

  func stopEventMonitoring() {
    eventMonitorGeneration &+= 1
    let monitor = eventTask
    eventTask = nil
    monitor?.cancel()

    eventRefreshGeneration &+= 1
    let refresh = eventRefreshTask
    eventRefreshTask = nil
    refresh?.cancel()

    eventStreamConnected = false
    eventStreamDetail = isReady
      ? "Paused while Hue Board is inactive."
      : "Unavailable until a Bridge is connected."
  }

  private func isFatalEventStreamError(_ error: Error) -> Bool {
    guard let error = error as? HueBoardError else { return false }
    switch error {
    case .authorization(_), .unsupported(_), .invalidResponse(_):
      return true
    case .invalidColor(_), .missingResource(_), .network(_), .cancelled:
      return false
    }
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
    eventRefreshGeneration &+= 1
    let generation = eventRefreshGeneration
    let previous = eventRefreshTask
    eventRefreshTask = nil
    previous?.cancel()

    eventRefreshTask = Task { [weak self] in
      guard let self else { return }
      defer {
        if self.eventRefreshGeneration == generation {
          self.eventRefreshTask = nil
        }
      }

      do {
        try await Task.sleep(for: .milliseconds(750))
      } catch {
        return
      }
      guard self.eventRefreshGeneration == generation else { return }

      while self.isBusy, !Task.isCancelled,
        self.eventRefreshGeneration == generation
      {
        do {
          try await Task.sleep(for: .milliseconds(500))
        } catch {
          return
        }
      }
      guard !Task.isCancelled,
        self.eventRefreshGeneration == generation,
        let profile = self.profile,
        let credential = self.credential
      else { return }

      do {
        let values = try await self.client.inventory(
          profile: profile,
          credential: credential
        )
        guard self.eventRefreshGeneration == generation,
          self.profile?.bridgeID == profile.bridgeID
        else { return }

        self.areas = values
        if !values.contains(where: { $0.id == self.selectedAreaID }) {
          self.selectedAreaID = values.first?.id
          try await self.persistence.saveSelectedAreaID(
            self.selectedAreaID,
            bridgeID: profile.bridgeID
          )
        }
      } catch {
        guard self.eventRefreshGeneration == generation else { return }
        self.eventStreamDetail =
          "Push updates remain connected, but structural refresh failed: \(error.localizedDescription)"
      }
    }
  }
}
